// Instant loading UI for /restaurantes/[id] (Next.js loading.js
// convention). Only visible once a real network call is in the request
// path — the default mock-backed data layer resolves synchronously, so
// this never renders until NEXT_PUBLIC_API_BASE_URL is set. Server
// Component, no data needed.

export default function MerchantLoading() {
  return (
    <main
      aria-busy="true"
      aria-live="polite"
      className="mx-auto flex w-full max-w-3xl flex-1 flex-col gap-4 pb-16"
    >
      <span className="sr-only">Cargando restaurante…</span>

      <div className="h-[232px] w-full animate-pulse bg-surface-2" />

      <div className="flex flex-col gap-4 px-5 sm:px-6">
        <div className="flex flex-col gap-2">
          <div className="h-7 w-2/3 animate-pulse rounded-full bg-surface" />
          <div className="h-4 w-1/2 animate-pulse rounded-full bg-surface" />
        </div>
        <div className="h-24 w-full animate-pulse rounded-2xl border border-border bg-surface" />
        <div className="h-40 w-full animate-pulse rounded-2xl border border-border bg-surface" />
      </div>
    </main>
  );
}
