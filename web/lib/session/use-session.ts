"use client";

/**
 * Placeholder session accessor. Auth isn't wired up yet — see
 * `lib/api/README.md`'s "Out of scope: auth" section and
 * `openspec/changes/fudo-consumers-mvp/design.md` (email+password only,
 * no OAuth) — this only exists so layout/nav code has one place to ask
 * "is there a logged-in consumer?" instead of hardcoding `false` inline.
 *
 * Swap the body of this hook for a real check (cookie/session read, a
 * Riverpod-equivalent provider, etc.) when auth lands; every call site below
 * already reacts to `isAuthenticated` correctly.
 */
export function useSession(): { isAuthenticated: boolean } {
  return { isAuthenticated: false };
}
