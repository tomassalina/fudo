// Shared skeleton markup for /buscar's "still loading" states — the Next.js
// route-level Suspense fallback (app/buscar/loading.tsx, shown during
// real-API navigations) and the AI search resolver's own pending state
// (AiSearchResolver.tsx, shown while POST /api/v1/search resolves) render
// the exact same shape, so this is extracted once instead of hand-copying
// the markup in both places.

export function BuscarSkeleton() {
  return (
    <>
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
    </>
  );
}
