"use client";

import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { PhoneNav } from "./PhoneNav";
import { WideNav } from "./WideNav";

/**
 * Structural phone/wide switch for navigation chrome — the design's only
 * fixed breakpoint (900px, see `useIsPhoneViewport`). Phone gets the
 * floating bottom pill with the raised QR action; wide gets the sticky top
 * bar. Never both, and never a CSS-only `hidden md:flex` swap: the two
 * layouts are structurally different (fixed/floating vs. sticky/in-flow),
 * matching how the design reference itself branches on `isPhone`/`isWide`.
 */
export function AppNav() {
  const isPhone = useIsPhoneViewport();
  return isPhone ? <PhoneNav /> : <WideNav />;
}
