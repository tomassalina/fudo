"use client";

import { usePathname, useSearchParams } from "next/navigation";
import { useEffect } from "react";
import { capture, isPostHogEnabled } from "@/lib/analytics/posthog";

/**
 * Fires a manual `$pageview` on every route change. posthog-js's built-in
 * `capture_pageview` autocapture doesn't hook App Router's client-side
 * navigations, so this is the standard workaround: read the current
 * pathname/search params and capture on change.
 *
 * Uses useSearchParams, so it must be rendered inside a <Suspense> boundary
 * (see app/layout.tsx) — otherwise a static/prerendered route would force
 * the whole tree above it into client-side rendering.
 */
export function PostHogPageview() {
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const search = searchParams.toString();

  useEffect(() => {
    if (!isPostHogEnabled) return;
    const url = search ? `${pathname}?${search}` : pathname;
    capture("$pageview", { $current_url: url });
  }, [pathname, search]);

  return null;
}
