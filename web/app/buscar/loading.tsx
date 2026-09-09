// Instant loading UI for /buscar (Next.js loading.js convention). Only
// visible once a real network call is in the request path — the default
// mock-backed data layer resolves synchronously, so this never renders
// until NEXT_PUBLIC_API_BASE_URL is set. Server Component, no data needed.
//
// Markup lives in BuscarSkeleton (shared with AiSearchResolver.tsx, the home
// hero AI search's own pending state) — mirrors BuscarView's fluid grid
// shape (see components/features/buscar/SearchResultsGrid.tsx) with
// `auto-fit`/`minmax` instead of a fixed breakpoint, so it doesn't jump when
// the real content swaps in.

import { FluidContainer } from "@/components/ui/FluidContainer";
import { BuscarSkeleton } from "@/components/features/buscar/BuscarSkeleton";

export default function BuscarLoading() {
  return (
    <FluidContainer
      as="main"
      aria-busy="true"
      aria-live="polite"
      className="flex flex-1 flex-col gap-6 py-8"
    >
      <BuscarSkeleton />
    </FluidContainer>
  );
}
