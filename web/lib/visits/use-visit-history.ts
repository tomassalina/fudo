"use client";

import { useEffect, useSyncExternalStore } from "react";
import { fetchVisits, fetchVisitSummaries, type RawVisit, type RawVisitSummary } from "@/lib/api/visits";
import { ApiError } from "@/lib/api/client";
import { getStoredToken } from "@/lib/auth/token-storage";
import { forceLogout, subscribeToSession } from "@/lib/session/session-provider";

export interface UseVisitHistory {
  visits: RawVisit[];
  visitSummaries: RawVisitSummary[];
  loading: boolean;
  error: boolean;
}

/**
 * Backs Perfil's "Visitas" tab (real `GET /api/v1/visits` +
 * `GET /api/v1/visit_summaries` — see lib/api/visits.ts) and LoyaltyCard's
 * per-merchant visit count. Both call this hook independently (PerfilView
 * and LoyaltyCard can be mounted at the same time), so — same reasoning as
 * lib/favorites/favorites-store.ts — this is a module-level external store
 * (`useSyncExternalStore`) rather than a plain per-instance
 * `useEffect`/`useState` hook: one shared fetch/cache instead of duplicate
 * requests per mounted component, and one place to resync every consumer of
 * this hook when the session changes.
 *
 * `subscribeToSession()` (lib/session/session-provider.tsx) is why this
 * resyncs on login/register/logout/forceLogout while a component stays
 * mounted, not just on that component's own mount — without it, an
 * already-mounted `LoyaltyCard` (rendered on the public, unauthenticated-
 * reachable merchant detail page) kept showing a stale, previous consumer's
 * visit count after a forced logout, since nothing told this store's
 * `state`/`loadedForToken` to reset. Same bug class, same fix, as the one
 * documented on favorites-store.ts's own `subscribeToSession` call.
 *
 * Guarded on `getStoredToken()` before fetching (same as favorites-store.ts's
 * `ensureLoaded`), NOT just left to fail with a 401 — this hook is also used
 * from `LoyaltyCard`, so it must never fire an authenticated request for a
 * visitor who was never logged in to begin with.
 */

interface VisitState {
  visits: RawVisit[];
  visitSummaries: RawVisitSummary[];
  loading: boolean;
  error: boolean;
}

let state: VisitState = { visits: [], visitSummaries: [], loading: true, error: false };
// The token `state` was loaded for — `undefined` means "never loaded",
// distinct from `null` ("loaded, and confirmed logged out") so a fresh
// module always attempts one real load instead of assuming "no token" up
// front. Same convention as favorites-store.ts's `loadedForToken`.
let loadedForToken: string | null | undefined;
let loadInFlight: Promise<void> | null = null;
const listeners = new Set<() => void>();

function notify() {
  for (const listener of listeners) listener();
}

function subscribe(listener: () => void) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function getSnapshot(): VisitState {
  return state;
}

// Stable reference reused across every call — `useSyncExternalStore` requires
// `getServerSnapshot` to return a cached value, not a fresh object literal
// each time, or React throws "The result of getServerSnapshot should be
// cached to avoid an infinite loop" (only reproduces logged-out, since an
// authenticated load settles `state` via `getSnapshot` before this matters).
const SERVER_SNAPSHOT: VisitState = { visits: [], visitSummaries: [], loading: true, error: false };

function getServerSnapshot(): VisitState {
  return SERVER_SNAPSHOT;
}

function setState(next: Partial<VisitState>) {
  state = { ...state, ...next };
  notify();
}

/** Loads this consumer's visits/visit_summaries once per token — a no-op if
 * already loaded for the current token (including "loaded, logged out"),
 * and de-duplicated against a load already in flight (every mounted
 * `useVisitHistory()` caller calls this on mount). */
async function ensureLoaded(): Promise<void> {
  const token = getStoredToken();
  if (token === loadedForToken) return;
  if (loadInFlight) {
    await loadInFlight;
    // The in-flight load may have settled state for a token that's no
    // longer current: a 401 here triggers `forceLogout()` synchronously
    // from inside the `catch` below, which re-enters `ensureLoaded()` via
    // `subscribeToSession` *while the original load is still finishing* —
    // that re-entrant call lands right here (`loadInFlight` still set) and,
    // if it just returned, would leave `state.loading` stuck at `true`
    // forever (the resync handler sets it `true` expecting a load to settle
    // it, but this branch was a no-op). Recursing re-checks `token` against
    // `loadedForToken` now that the in-flight load has finished: if they
    // already match, this immediately no-ops (base case); if not (as in the
    // 401 case above, where `loadedForToken` is deliberately left unset so
    // a real retry can happen), it becomes the new leader and actually
    // loads/settles for the current token instead of leaving state stale.
    return ensureLoaded();
  }

  loadInFlight = (async () => {
    if (!token) {
      loadedForToken = null;
      setState({ visits: [], visitSummaries: [], error: false, loading: false });
      return;
    }
    try {
      const [visits, visitSummaries] = await Promise.all([fetchVisits(), fetchVisitSummaries()]);
      loadedForToken = token;
      setState({ visits, visitSummaries, error: false, loading: false });
    } catch (caught) {
      // Leave `loadedForToken` unset so a future `ensureLoaded()` call
      // (e.g. after a real reconnect) retries instead of caching a failure
      // forever — same reasoning as favorites-store.ts's `handleFavoriteError`.
      if (caught instanceof ApiError && caught.status === 401) {
        forceLogout();
      } else {
        setState({ error: true, loading: false });
      }
    }
  })();

  try {
    await loadInFlight;
  } finally {
    loadInFlight = null;
  }
}

// Resync with the session, not just with each hook's own mount. See the
// header comment above for why this is required.
subscribeToSession(() => {
  const token = getStoredToken();
  if (token === loadedForToken) return;
  loadedForToken = undefined;
  setState({ visits: [], visitSummaries: [], loading: true, error: false });
  void ensureLoaded();
});

export function useVisitHistory(): UseVisitHistory {
  const snapshot = useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);

  useEffect(() => {
    void ensureLoaded();
  }, []);

  return snapshot;
}
