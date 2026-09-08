// Server Component (default) — public landing page, rendered at `/`.
//
// Visual design is a placeholder. Real design comes from a Claude Design
// prototype (not yet shared as of this scaffold). Dark background + violet
// accent (see globals.css) is a rough approximation — replace when the
// real design is integrated.

export default function MarketingLandingPage() {
  return (
    <main className="flex flex-1 flex-col items-center justify-center gap-4 px-6 text-center">
      <h1 className="text-4xl font-semibold tracking-tight text-foreground sm:text-5xl">
        Fudo Consumers{" "}
        <span className="text-accent-light">— próximamente</span>
      </h1>
      <p className="max-w-md text-base text-foreground/70">
        Estamos preparando la experiencia para descubrir y pedir en tus
        locales favoritos.
      </p>
    </main>
  );
}
