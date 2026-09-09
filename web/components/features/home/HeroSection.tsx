"use client";

// Hero section shell for the home page. Min-height and the decorative
// background glow both switch at the design's one real breakpoint (900px,
// via useIsPhoneViewport) instead of Tailwind's `sm:` (640px) — see
// docs/design-reference/Fudo App.dc.html (phone: 540x430 glow, blur(20px))
// vs docs/design-reference/Fudo Customers.dc.html (wide: 1100x700 glow,
// blur(30px)) and lib/hooks/use-viewport.ts. Lifted out of the (server) page
// component, same pattern as components/layout/nav/AppNav.tsx, so the switch
// reads the real viewport instead of a CSS media query that doesn't line up
// with the app's structural breakpoint.
//
// Home has no content below the hero, so this section is sized to fill the
// *entire* space left over after chrome — not just a minimum — and centers
// its children in it, so the search card is always dead-center of the
// available viewport rather than pinned near the top:
//   - phone: 100vh minus Header's own height (~52px, the same offset the
//     wide branch below applies for its sticky nav) minus 112px (`pb-28`,
//     the same bottom-nav clearance used everywhere else in this app — see
//     e.g. app/buscar/page.tsx — reserved here so the centered content never
//     sits under PhoneNav's floating pill, which overlays rather than
//     reserving layout space).
//   - wide: 100vh minus WideNav's sticky height (68px, its `h-17`).

import type { ReactNode } from "react";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { cn } from "@/lib/utils/cn";

export function HeroSection({ children }: { children: ReactNode }) {
  const isPhone = useIsPhoneViewport();

  return (
    <section
      className={cn(
        "relative flex items-center justify-center overflow-hidden py-10",
        isPhone ? "min-h-[calc(100vh-164px)]" : "min-h-[calc(100vh-68px)]",
      )}
    >
      {/* Single soft radial glow behind the hero, per the reference's
          background treatment — the reference also scatters small "+"
          glyphs and dots around it; those are decorative noise, not
          structural, so they're intentionally left out here. */}
      <div
        aria-hidden
        className={cn(
          "pointer-events-none absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 rounded-full opacity-70",
          isPhone ? "h-[430px] w-[540px] blur-[20px]" : "h-[700px] w-[1100px] blur-[30px]",
        )}
        style={{
          background:
            "radial-gradient(closest-side, rgba(255,80,35,0.28), rgba(255,80,35,0.07) 55%, rgba(255,80,35,0) 78%)",
        }}
      />

      {children}
    </section>
  );
}
