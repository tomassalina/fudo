// Instant loading UI for /buscar (Next.js loading.js convention). Only
// visible once a real network call is in the request path — the default
// mock-backed data layer resolves synchronously, so this never renders
// until NEXT_PUBLIC_API_BASE_URL is set. Server Component, no data needed.
//
// Mirrors BuscarView's fluid grid shape (see components/features/buscar/
// SearchResultsGrid.tsx) with `auto-fit`/`minmax` instead of a fixed
// breakpoint, so it doesn't jump when the real content swaps in.

import { FluidContainer } from "@/components/ui/FluidContainer";

export default function BuscarLoading() {
  return (
    <FluidContainer
      as="main"
      aria-busy="true"
      aria-live="polite"
      className="flex flex-1 flex-col gap-6 py-8"
    >
      <span className="sr-only">Buscando lugares…</span>

      <div className="h-14 w-full animate-pulse rounded-[26px] bg-surface" />
      <div className="flex gap-2">
        {/* Static skeleton, no stable id to key by. */}
        {Array.from({ length: 4 }).map((_, index) => (
          <div
            key={index}
            className="h-7 w-20 animate-pulse rounded-full bg-surface"
          />
        ))}
      </div>

      <div className="grid grid-cols-[repeat(auto-fit,minmax(260px,1fr))] gap-[18px]">
        {/* Static skeleton, no stable id to key by. */}
        {Array.from({ length: 6 }).map((_, index) => (
          <div
            key={index}
            className="h-[240px] w-full animate-pulse rounded-card border border-border bg-surface"
          />
        ))}
      </div>
    </FluidContainer>
  );
}
