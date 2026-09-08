"use client";

import { useEffect, type ReactNode } from "react";
import { initPostHogClient } from "@/lib/analytics/posthog";

/**
 * Initializes PostHog once on mount, then renders children unchanged.
 * A no-op when NEXT_PUBLIC_POSTHOG_KEY/HOST aren't set — see
 * lib/analytics/posthog.ts.
 */
export function PostHogProvider({ children }: { children: ReactNode }) {
  useEffect(() => {
    initPostHogClient();
  }, []);

  return children;
}
