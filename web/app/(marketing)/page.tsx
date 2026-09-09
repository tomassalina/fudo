// Server Component (default) — public landing page, rendered at `/`.
//
// Structure and copy come from the design reference's `isHome` view:
//   docs/design-reference/Fudo App.dc.html        (phone, vw < 900)
//   docs/design-reference/Fudo Customers.dc.html  (wide, vw >= 900)
// The hero (headline + typewriter search card) is the one client island —
// see components/features/home/HeroSearch.tsx — everything else, including
// the featured-places fetch, stays server-rendered.

import { FluidContainer } from "@/components/ui/FluidContainer";
import { HeroSection } from "@/components/features/home/HeroSection";
import { HeroSearch } from "@/components/features/home/HeroSearch";
import { FeaturedGrid } from "@/components/features/home/FeaturedGrid";
import { getMerchants } from "@/lib/data/merchants";

const FEATURED_COUNT = 6;

export default async function MarketingLandingPage() {
  const merchants = await getMerchants();
  const featured = merchants.slice(0, FEATURED_COUNT);

  return (
    <main className="flex flex-1 flex-col">
      <HeroSection>
        <FluidContainer className="relative animate-fudo-fade">
          <HeroSearch />
        </FluidContainer>
      </HeroSection>

      {featured.length > 0 ? (
        <FluidContainer as="section" className="flex flex-col gap-4 pb-28">
          <h2 className="font-heading text-title-fluid font-black text-foreground">
            Lugares destacados
          </h2>
          <FeaturedGrid merchants={featured} />
        </FluidContainer>
      ) : null}
    </main>
  );
}
