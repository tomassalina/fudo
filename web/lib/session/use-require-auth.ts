"use client";

import { useCallback, useEffect, useRef, useSyncExternalStore } from "react";
import { useRouter } from "next/navigation";
import { useSession } from "./use-session";

// The canonical "has this component hydrated on the client yet" hook,
// built on the exact same `useSyncExternalStore` hydration-correction
// mechanism `session-provider.tsx`'s own store uses — `false` on the server
// and the first client render (matching SSR), `true` once React's built-in
// post-hydration correction re-renders with the client snapshot. Chosen
// over a plain `useState(false)` + `useEffect(() => setMounted(true), [])`
// specifically because this project's lint config
// (`react-hooks/set-state-in-effect`) flags unconditional `setState` calls
// inside an effect body — this sidesteps that by never calling `setState`
// at all, while keeping the exact same "false, then true" timing this hook
// depends on (see the header comment below for why that timing matters).
// `subscribe` is a no-op (never notifies) since this value only ever
// changes via React's own hydration correction, not a real external event.
function subscribeNever() {
  return () => {};
}

function useHasHydrated(): boolean {
  return useSyncExternalStore(
    subscribeNever,
    () => true,
    () => false,
  );
}

export interface RequireAuthResult {
  /**
   * True once the client has confirmed a real, persisted session exists —
   * safe to render authenticated-only UI. False both while the real session
   * state is still settling (see the header comment below) and once
   * genuinely logged out (a redirect to `/login` is already in flight by
   * then).
   */
  ready: boolean;
  /**
   * Call right before an intentional logout that navigates somewhere OTHER
   * than `/login` (e.g. "Cerrar sesión" → home) — suppresses exactly the
   * next would-be redirect-to-`/login` so it doesn't race the caller's own
   * navigation.
   */
  suppressNextRedirect: () => void;
}

/**
 * Gate for any page that requires a session (currently just PerfilView) —
 * redirects to `/login` when there is no session, but only once `mounted`
 * confirms the client has read the REAL session state.
 *
 * WHY THIS EXISTS (root cause of the `/perfil` hard-reload bug):
 * `useSession()`'s `isAuthenticated` is backed by `useSyncExternalStore`
 * (session-provider.tsx). React's hydration contract requires the very
 * first CLIENT render to reuse `getServerSnapshot()` (always "logged out")
 * so it matches the server-rendered HTML — even when a valid session sits
 * in localStorage. React does correct this by re-rendering with the real
 * client snapshot right after mount, but that correction itself runs inside
 * a `useEffect` belonging to `SessionProvider`, and a naive
 * `useEffect(() => { if (!isAuthenticated) router.replace("/login") })` in a
 * CHILD page fires BEFORE that correction: child passive effects run before
 * their ancestor's in the same commit, and `SessionProvider` is always an
 * ancestor of any page reading `useSession()`. The result: a real,
 * logged-in consumer gets bounced to `/login` on every hard reload, before
 * the correction ever runs — `router.replace` has already navigated away by
 * the time `isAuthenticated` turns `true` a moment later.
 *
 * Confirmed empirically (not just theorized) with a `renderToString` +
 * `hydrateRoot` reproduction before writing this fix — see
 * `__tests__/lib/session/perfil-hydration-redirect.test.tsx`, which fails
 * against the naive pattern and passes with this hook.
 *
 * The fix: gate the redirect on an explicit `mounted` flag (`useHasHydrated`
 * above) that only flips `true` on the SAME settle pass as the corrected
 * `isAuthenticated` — both are `useSyncExternalStore` hydration corrections
 * triggered from within that first passive-effects flush, so React batches
 * them into one consistent follow-up render. The very first effect run
 * (`mounted` still `false`) therefore never acts on the not-yet-settled
 * value — confirmed empirically, see the test referenced above.
 */
export function useRequireAuth(): RequireAuthResult {
  const router = useRouter();
  const { isAuthenticated } = useSession();
  const mounted = useHasHydrated();
  const suppressRef = useRef(false);

  useEffect(() => {
    if (!mounted || isAuthenticated) return;
    if (suppressRef.current) {
      suppressRef.current = false;
      return;
    }
    router.replace("/login");
  }, [mounted, isAuthenticated, router]);

  const suppressNextRedirect = useCallback(() => {
    suppressRef.current = true;
  }, []);

  return { ready: mounted && isAuthenticated, suppressNextRedirect };
}
