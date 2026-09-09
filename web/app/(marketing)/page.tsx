// Server Component (default) — public landing page, rendered at `/`.
//
// Structure and copy come from the design reference's `isHome` view:
//   docs/design-reference/Fudo App.dc.html        (phone, vw < 900)
//   docs/design-reference/Fudo Customers.dc.html  (wide, vw >= 900)
// The hero (headline + typewriter search card) is the one client island —
// see components/features/home/HeroSearch.tsx — everything else stays
// server-rendered.
//
// Home is intentionally just the hero: no featured-merchants section below
// it (see FeaturedGrid, still used nowhere but kept around in case it's
// reused elsewhere — this page just doesn't render it). HeroSection itself
// is sized to the full viewport minus header/nav chrome and centers its
// children within that space, so the search card always sits dead-center of
// the screen instead of pinned to the top.

import { FluidContainer } from "@/components/ui/FluidContainer";
import { Header } from "@/components/layout/Header";
import { HeroSection } from "@/components/features/home/HeroSection";
import { HeroSearch } from "@/components/features/home/HeroSearch";

export default function MarketingLandingPage() {
  return (
    <main className="flex flex-1 flex-col">
      <Header />
      <HeroSection>
        <FluidContainer className="relative animate-fudo-fade">
          <HeroSearch />
        </FluidContainer>
      </HeroSection>
    </main>
  );
}
