"use client";

// Shared "is the phone full-screen map view open?" flag.
//
// PhoneNav's floating pill auto-hides on scroll-down via `useScrollDirection`
// (see that hook's own doc comment) — the right behavior for the results
// *list*. The /buscar map view has the opposite, explicit requirement: the
// bottom nav must stay visible at all times while the map is open, even
// while panning/zooming it (unlike the list, which is allowed to hide it).
// Leaflet's drag/zoom handlers don't reliably produce `window.scroll` events
// either way, but this makes the guarantee explicit instead of depending on
// that incidental behavior.
//
// PhoneNav (mounted once, near the app root by AppNav) and MapToggleSection
// (mounted deep inside /buscar) don't share a common client-state parent
// short of the whole app, and this is a single boolean — not app state that
// justifies a Context provider. Same `useSyncExternalStore` shape as
// `use-viewport.ts` for the same reason: a plain module-level store, no
// re-render unless the flag actually flips.

import { useSyncExternalStore } from "react";

let active = false;
const listeners = new Set<() => void>();

function subscribe(onStoreChange: () => void) {
  listeners.add(onStoreChange);
  return () => listeners.delete(onStoreChange);
}

function getSnapshot() {
  return active;
}

function getServerSnapshot() {
  return false;
}

/** Call when the phone full-screen map view opens/closes to lock/unlock PhoneNav's visibility. */
export function setMapModeActive(next: boolean) {
  if (active === next) return;
  active = next;
  listeners.forEach((listener) => listener());
}

/** `true` while the phone full-screen map view is open — see file doc comment. */
export function useMapModeActive(): boolean {
  return useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);
}
