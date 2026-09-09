"use client";

import { useSyncExternalStore } from "react";

/**
 * The design's one hard breakpoint: below 900px the app uses the phone
 * layout (bottom floating nav, single column); at or above it, the wide
 * layout (sticky top nav, multi-column grids). See
 * `docs/design-reference/Fudo Customers.dc.html`, where `isPhone`/`isWide`
 * are derived from this exact same `vw < 900` check on `window.innerWidth`.
 *
 * Everything else in the design is fluid (clamp() type, `min(92vw, …)`
 * containers, `auto-fit`/`auto-fill` grids) — this is deliberately the only
 * place a fixed pixel threshold makes a structural decision.
 */
const PHONE_MAX_WIDTH = 900;

function subscribe(onStoreChange: () => void) {
  window.addEventListener("resize", onStoreChange);
  return () => window.removeEventListener("resize", onStoreChange);
}

function getSnapshot() {
  return window.innerWidth < PHONE_MAX_WIDTH;
}

// Wide is the safer server/first-paint guess: it renders without the
// floating nav overlapping content, and most links (search engines, shared
// previews) land on desktop-class viewports.
function getServerSnapshot() {
  return false;
}

export type Viewport = "phone" | "wide";

/** `true` while the viewport is under the design's 900px phone/wide switch. */
export function useIsPhoneViewport(): boolean {
  return useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);
}

/** Same switch as {@link useIsPhoneViewport}, spelled as the two named states. */
export function useViewport(): Viewport {
  return useIsPhoneViewport() ? "phone" : "wide";
}
