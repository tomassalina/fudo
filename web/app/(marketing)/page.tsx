// Server Component (default) — public landing page, rendered at `/`.
//
// Kept intentionally modest: this is the lowest-priority piece of the
// product (a public, SEO-oriented entry point into the Buscar experience),
// not a marketing site to over-invest in. Visual tokens now come from the
// real design reference (see globals.css) instead of the earlier violet
// placeholder guess.

import Link from "next/link";

export default function MarketingLandingPage() {
  return (
    <main className="flex flex-1 flex-col items-center justify-center gap-6 px-6 py-16 text-center">
      <h1 className="max-w-2xl font-heading text-4xl font-black leading-tight tracking-tight text-foreground sm:text-5xl">
        Encontrá dónde comer.{" "}
        <span className="italic text-accent">Ganá descuentos</span> por cada
        visita.
      </h1>
      <p className="max-w-md text-base text-foreground-muted">
        Buscá restaurantes, bares y cafés cerca tuyo en lenguaje natural, y
        sumá recompensas en tus locales favoritos cada vez que volvés.
      </p>
      <Link
        href="/buscar"
        className="rounded-full bg-accent px-6 py-3 font-semibold text-white transition-colors hover:bg-accent-dark"
      >
        Buscar un lugar
      </Link>
    </main>
  );
}
