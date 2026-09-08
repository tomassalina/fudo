// Public, SSR search page — the only piece of the mobile app's 3 tabs this
// web platform surfaces (see PRD: web is the lowest-priority, SEO-oriented
// slice of just "Buscar"). Server Component: data and filtering happen here,
// the only client-side bit is the placeholder rotation in <SearchBar>.
//
// Search itself is a plain GET form (?q=...), so it works without JS and is
// fully crawlable/linkable — no real backend yet, so it filters the real
// fixture dataset (lib/mock) instead of calling an API.

import Link from "next/link";
import { SearchBar } from "@/components/buscar/SearchBar";
import { MerchantCard } from "@/components/buscar/MerchantCard";
import { MapPanel } from "@/components/buscar/MapPanel";
import { MOCK_MERCHANTS, MERCHANT_TYPE_LABELS } from "@/lib/mock/merchants";
import { searchMerchants, QUICK_FILTER_TYPES } from "@/lib/mock/search";

export default async function BuscarPage({
  searchParams,
}: PageProps<"/buscar">) {
  const params = await searchParams;
  const rawQuery = params.q;
  const query = typeof rawQuery === "string" ? rawQuery : "";

  const results = searchMerchants(MOCK_MERCHANTS, query);
  const countLabel =
    results.length === 1
      ? "1 lugar encontrado"
      : `${results.length} lugares encontrados`;

  return (
    <main className="mx-auto flex w-full max-w-5xl flex-1 flex-col gap-6 px-6 py-8">
      <div className="flex flex-col gap-4">
        <SearchBar defaultValue={query} />

        <div className="flex flex-wrap gap-2">
          {QUICK_FILTER_TYPES.map((type) => (
            <Link
              key={type}
              href={`/buscar?q=${encodeURIComponent(type)}`}
              className="rounded-full border border-border bg-surface px-3 py-1.5 text-[13px] font-semibold text-foreground-muted transition-colors hover:border-accent/50 hover:text-foreground"
            >
              {MERCHANT_TYPE_LABELS[type]}
            </Link>
          ))}
        </div>
      </div>

      <div className="grid flex-1 gap-6 lg:grid-cols-[minmax(0,1fr)_360px]">
        <section className="flex flex-col gap-3">
          <div className="flex items-baseline justify-between px-1">
            <span className="text-[13px] text-foreground-muted">
              {countLabel}
            </span>
            {query ? (
              <Link
                href="/buscar"
                className="text-[13px] font-semibold text-accent hover:text-accent-light"
              >
                Limpiar búsqueda
              </Link>
            ) : null}
          </div>

          {results.length > 0 ? (
            <div className="flex flex-col gap-3">
              {results.map((merchant) => (
                <MerchantCard key={merchant.id} merchant={merchant} />
              ))}
            </div>
          ) : (
            <div className="flex flex-col items-center gap-3 rounded-2xl border border-border bg-surface px-6 py-12 text-center">
              <p className="font-heading text-lg font-bold text-foreground">
                No encontramos lugares para &ldquo;{query}&rdquo;
              </p>
              <Link
                href="/buscar"
                className="rounded-full bg-accent-soft px-4 py-2 text-[13px] font-semibold text-accent-light"
              >
                Ver todos los lugares
              </Link>
            </div>
          )}
        </section>

        <aside className="lg:sticky lg:top-20 lg:h-[calc(100vh-6rem)]">
          <MapPanel merchants={results} />
        </aside>
      </div>
    </main>
  );
}
