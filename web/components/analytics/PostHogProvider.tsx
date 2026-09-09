"use client";

import type { ReactNode } from "react";
// Imported for its module-scope side effect: posthog.init() runs there,
// synchronously, during module evaluation — i.e. before React starts
// rendering/mounting anything. That guarantees it runs before any child
// tracker's own mount effect could call capture(). See the comment in
// lib/analytics/posthog.ts for why this can't be a useEffect here: React
// runs child effects before a parent's own effect on mount, so an
// effect-based init would let a child's first capture() call race ahead of
// init() and get silently dropped by posthog-js's __loaded gate.
import "@/lib/analytics/posthog";

/**
 * Renders children unchanged. Its only job is to be the client-boundary
 * that pulls lib/analytics/posthog.ts into the client bundle so its
 * module-scope posthog.init() call runs. A no-op when
 * NEXT_PUBLIC_POSTHOG_KEY/HOST aren't set — see lib/analytics/posthog.ts.
 */
export function PostHogProvider({ children }: { children: ReactNode }) {
  return children;
}
