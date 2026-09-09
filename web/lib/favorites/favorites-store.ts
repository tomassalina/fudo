"use client";

// Client-side "favorited merchant ids" — backs the heart toggle on merchant
// cards/detail pages (components/features/buscar/FavoriteButton.tsx) and
// the Perfil "Favoritos" tab (components/features/perfil/FavoritesTab.tsx).
//
// Now backed for real by `GET/POST/DELETE /api/v1/favorites`
// (backend/app/controllers/api/v1/favorites_controller.rb, via
// lib/api/favorites.ts) — this used to be `localStorage`-only, because
// reaching that endpoint needed a real bearer token that didn't exist yet
// (see session-provider.tsx). There is no mock/anonymous mode here anymore:
// favoriting only exists for a real, logged-in consumer, so
// `toggleFavoriteMerchant` is a silent no-op while logged out (see below)
// instead of a fake localStorage-only favorite that would vanish/never
// existed the moment auth became real.
//
// This keeps the exact same external-store shape
// (`useFavoriteMerchantIds`/`useIsMerchantFavorite`/`toggleFavoriteMerchant`)
// call sites already use — same pattern `lib/location/use-location.ts` uses
// for "state that must survive a reload and must never cause a
// server/first-paint hydration mismatch" — but the network fetch that
// hydrates it is triggered from `useFavoriteMerchantIds` (a hook, where a
// `useEffect` is allowed), not from `getSnapshot` itself (which must stay a
// pure, side-effect-light read for `useSyncExternalStore`'s contract).
//
// Not optimistic: `toggleFavoriteMerchant` waits for the real
// POST/DELETE to resolve before flipping the heart, same tradeoff as
// `useNotificationsSetting` (lib/consumer-settings/use-notifications-setting.ts)
// and for the same reason — simpler and safer than reconciling an
// optimistic add against the real `favorite.id` DELETE needs, at the cost
// of one round-trip of visible delay.

import { useEffect, useSyncExternalStore } from "react";
import {
  createFavorite,
  deleteFavorite,
  fetchFavorites,
  type RawFavorite,
} from "@/lib/api/favorites";
import { ApiError } from "@/lib/api/client";
import { getStoredToken } from "@/lib/auth/token-storage";
import { forceLogout, subscribeToSession } from "@/lib/session/session-provider";

type Listener = () => void;

interface FavoriteEntry {
  merchantId: number;
  favoriteId: number;
}

let entries: FavoriteEntry[] = [];
// The token these `entries` were loaded for — `undefined` means "never
// loaded", distinct from `null` ("loaded, and confirmed logged out") so a
// fresh module always attempts one real load instead of assuming "no
// token" up front.
let loadedForToken: string | null | undefined;
let loadInFlight: Promise<void> | null = null;
const listeners = new Set<Listener>();

function notify() {
  for (const listener of listeners) listener();
}

function subscribe(listener: Listener) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function currentIds(): number[] {
  return entries.map((entry) => entry.merchantId);
}

// Stable per-render-cycle reference: `useSyncExternalStore` requires
// `getSnapshot` to return a value that's `Object.is`-stable when nothing
// changed, or it re-renders forever. `entries` (module state) only ever
// gets reassigned (never mutated in place) by `setEntries`, so caching the
// derived id array alongside it is enough to keep this stable.
let cachedIds: number[] = [];
let cachedForEntries: FavoriteEntry[] = entries;

function getSnapshot(): number[] {
  if (cachedForEntries !== entries) {
    cachedIds = currentIds();
    cachedForEntries = entries;
  }
  return cachedIds;
}

function getServerSnapshot(): number[] {
  return [];
}

function setEntries(next: FavoriteEntry[]) {
  entries = next;
  notify();
}

function handleFavoriteError(error: unknown) {
  if (error instanceof ApiError && error.status === 401) {
    // Expired/invalid token on a protected call — clear the session so
    // useRequireAuth() (any page that requires one) redirects to /login,
    // per this session's auth-integration brief.
    forceLogout();
  }
  // Every other failure (network, 422 already-favorited from a stale
  // double-click, ...): nothing to reconcile since this store isn't
  // optimistic — the UI already reflects the last confirmed server state.
}

/** Loads this consumer's favorites once per token — a no-op if already
 * loaded for the current token (including "loaded, logged out"), and
 * de-duplicated against a load already in flight (every mounted
 * `FavoriteButton` + `FavoritesTab` calls this on mount). */
async function ensureLoaded(): Promise<void> {
  const token = getStoredToken();
  if (token === loadedForToken) return;
  if (loadInFlight) {
    await loadInFlight;
    return;
  }

  loadInFlight = (async () => {
    if (!token) {
      loadedForToken = null;
      setEntries([]);
      return;
    }
    try {
      const favorites = await fetchFavorites();
      loadedForToken = token;
      setEntries(favorites.map(toEntry));
    } catch (error) {
      // Leave `loadedForToken` unset so a future `ensureLoaded()` call
      // (e.g. after a real reconnect) retries instead of caching a failure
      // forever.
      handleFavoriteError(error);
    }
  })();

  try {
    await loadInFlight;
  } finally {
    loadInFlight = null;
  }
}

function toEntry(favorite: RawFavorite): FavoriteEntry {
  return { merchantId: favorite.merchant_id, favoriteId: favorite.id };
}

// Resync with the session, not just with each hook's own mount. Without
// this, an already-mounted `FavoriteButton` (e.g. on /buscar, which isn't
// gated by `useRequireAuth()`) kept showing its last-known heart state
// after a forced logout — this store's `entries`/`loadedForToken` are
// module state, independent of session-provider.tsx's, so nothing told it
// to reset. Fires on every login/register/logout/forceLogout: clears the
// stale snapshot synchronously (so no component can render or toggle a
// heart for a session that no longer applies) and re-triggers
// `ensureLoaded()` for whatever the new token is — a no-op fetch (empty
// list) when logged out, a real refetch for a newly logged-in consumer
// without requiring every mounted component to remount first.
subscribeToSession(() => {
  const token = getStoredToken();
  if (token === loadedForToken) return;
  setEntries([]);
  loadedForToken = undefined;
  void ensureLoaded();
});

/** Every favorited merchant id, in the order the backend returned them. */
export function useFavoriteMerchantIds(): number[] {
  const ids = useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);

  useEffect(() => {
    void ensureLoaded();
  }, []);

  return ids;
}

/** Whether one specific merchant is favorited — the hook `FavoriteButton` reads. */
export function useIsMerchantFavorite(merchantId: number): boolean {
  return useFavoriteMerchantIds().includes(merchantId);
}

/**
 * Adds or removes one merchant from the current consumer's real favorites.
 * Silently does nothing while logged out — there's no anonymous favoriting
 * once auth is real; callers (FavoriteButton, FavoritesTab) don't currently
 * render for a clearly-anonymous flow that would need its own "please log
 * in" affordance, so this stays a no-op rather than throwing.
 */
export function toggleFavoriteMerchant(merchantId: number): void {
  const token = getStoredToken();
  if (!token) return;

  const existing = entries.find((entry) => entry.merchantId === merchantId);

  if (existing) {
    deleteFavorite(existing.favoriteId)
      .then(() => {
        setEntries(entries.filter((entry) => entry.merchantId !== merchantId));
      })
      .catch(handleFavoriteError);
  } else {
    createFavorite(merchantId)
      .then((favorite) => {
        setEntries([...entries, toEntry(favorite)]);
      })
      .catch(handleFavoriteError);
  }
}
