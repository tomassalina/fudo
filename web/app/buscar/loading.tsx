// Instant loading UI for /buscar (Next.js loading.js convention). Only
// visible once a real network call is in the request path — the default
// mock-backed data layer resolves synchronously, so this never renders
// until NEXT_PUBLIC_API_BASE_URL is set. Server Component, no data needed.

export default function BuscarLoading() {
  return (
    <main
      aria-busy="true"
      aria-live="polite"
      className="mx-auto flex w-full max-w-5xl flex-1 flex-col gap-6 px-6 py-8"
    >
      <span className="sr-only">Buscando lugares…</span>

      <div className="flex flex-col gap-4">
        <div className="h-12 w-full animate-pulse rounded-full bg-surface" />
        <div className="flex gap-2">
          {/* Static skeleton, no stable id to key by. */}
          {Array.from({ length: 4 }).map((_, index) => (
            <div
              key={index}
              className="h-7 w-20 animate-pulse rounded-full bg-surface"
            />
          ))}
        </div>
      </div>

      <div className="grid flex-1 gap-6 lg:grid-cols-[minmax(0,1fr)_360px]">
        <section className="flex flex-col gap-3">
          {/* Static skeleton, no stable id to key by. */}
          {Array.from({ length: 4 }).map((_, index) => (
            <div
              key={index}
              className="h-28 w-full animate-pulse rounded-2xl border border-border bg-surface"
            />
          ))}
        </section>
        <aside className="hidden h-[calc(100vh-6rem)] animate-pulse rounded-2xl border border-border bg-surface lg:block" />
      </div>
    </main>
  );
}
