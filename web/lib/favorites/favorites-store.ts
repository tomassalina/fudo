"use client";

// Client-side "favorited merchant ids" — backs the heart toggle on merchant
// cards/detail pages (components/features/buscar/FavoriteButton.tsx) and
// the Perfil "Favoritos" tab (components/features/perfil/FavoritesTab.tsx).
//
// The real backend already exposes a per-consumer `favorites` resource
// (`GET/POST/DELETE /api/v1/favorites`, `backend/app/controllers/api/v1/
// favorites_controller.rb`, Fase 3) — confirmed present by reading the
// controller and routes, not assumed. It is NOT called from here: this
// entire web app's session is a mocked, local-only login
// (`lib/session/session-provider.tsx`'s own TODOs — no real
// `POST /api/v1/sessions` call anywhere) and `apiFetch` (`lib/api/client.ts`)
// has no bearer/JWT header support at all yet, so any authenticated request
// — this one included — would 401 unconditionally today. Wiring real
// consumer auth through the whole app is a separate, materially larger
// change than "add a Favoritos tab to Perfil", so until that lands, favorited
// ids live in `localStorage` only: same honest-mock architecture as
// `lib/mock/visit-history.ts` (plausible, not a live table) and the exact
// same external-store shape as `lib/location/use-location.ts` (state that
// must survive a reload and must never cause a server/first-paint hydration
// mismatch). Swap this module's internals for real `favorites` API calls
// once real consumer auth exists — every call site already reads through
// this module's public API, not `localStorage` directly, so that swap stays
// contained here.

import { useSyncExternalStore } from "react";

const STORAGE_KEY = "fudo:favorite-merchant-ids";

type Listener = () => void;

let favoriteIds: number[] = [];
let hydrated = false;
const listeners = new Set<Listener>();

function notify() {
  for (const listener of listeners) listener();
}

function subscribe(listener: Listener) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function isNumberArray(value: unknown): value is number[] {
  return Array.isArray(value) && value.every((entry) => typeof entry === "number");
}

function readStored(): number[] {
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return isNumberArray(parsed) ? parsed : [];
  } catch {
    // Corrupted or blocked storage (private mode, quota) — fall back to "no
    // favorites" instead of throwing during render.
    return [];
  }
}

function persist(ids: number[]) {
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(ids));
  } catch {
    // Storage blocked/full — state still updates in memory for this tab, it
    // just won't survive a reload.
  }
}

function getSnapshot(): number[] {
  if (!hydrated) {
    favoriteIds = readStored();
    hydrated = true;
  }
  return favoriteIds;
}

function getServerSnapshot(): number[] {
  return [];
}

function setFavoriteIds(next: number[]) {
  favoriteIds = next;
  hydrated = true;
  persist(next);
  notify();
}

/** Every favorited merchant id, in the order they were favorited. */
export function useFavoriteMerchantIds(): number[] {
  return useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);
}

/** Whether one specific merchant is favorited — the hook `FavoriteButton` reads. */
export function useIsMerchantFavorite(merchantId: number): boolean {
  return useFavoriteMerchantIds().includes(merchantId);
}

/** Adds or removes one merchant id from the favorited set. */
export function toggleFavoriteMerchant(merchantId: number): void {
  const current = getSnapshot();
  const next = current.includes(merchantId)
    ? current.filter((id) => id !== merchantId)
    : [...current, merchantId];
  setFavoriteIds(next);
}
