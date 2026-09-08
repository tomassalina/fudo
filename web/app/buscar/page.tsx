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
import { FilterChips } from "@/components/buscar/FilterChips";
import { MerchantCard } from "@/components/buscar/MerchantCard";
import { MapPanel } from "@/components/buscar/MapPanel";
import type { MerchantType } from "@/lib/types";
import {
  MOCK_MERCHANTS,
  MERCHANT_TYPES_IN_USE,
  TAGS_IN_USE,
} from "@/lib/mock/merchants";
import { searchMerchants } from "@/lib/mock/search";

function parseType(raw: string | string[] | undefined): MerchantType | null {
  const value = typeof raw === "string" ? raw : undefined;
  return value && (MERCHANT_TYPES_IN_USE as string[]).includes(value)
    ? (value as MerchantType)
    : null;
}

function parseTags(raw: string | string[] | undefined): string[] {
  const value = typeof raw === "string" ? raw : "";
  const requested = value
    .split(",")
    .map((tag) => tag.trim())
    .filter(Boolean);

  // Keep only real, filterable tags — an unknown value in the URL just gets
  // dropped instead of silently zeroing out the results.
  return TAGS_IN_USE.filter((tag) => requested.includes(tag));
}

export default async function BuscarPage({
  searchParams,
}: PageProps<"/buscar">) {
  const params = await searchParams;
  const rawQuery = params.q;
  const query = typeof rawQuery === "string" ? rawQuery : "";
  const type = parseType(params.type);
  const tags = parseTags(params.tags);
  const hasFilters = type !== null || tags.length > 0;

  const results = searchMerchants(MOCK_MERCHANTS, {
    query,
    type: type ?? undefined,
    tags,
  });
  const countLabel =
    results.length === 1
      ? "1 lugar encontrado"
      : `${results.length} lugares encontrados`;

  return (
    <main className="mx-auto flex w-full max-w-5xl flex-1 flex-col gap-6 px-6 py-8">
      <div className="flex flex-col gap-4">
        <SearchBar defaultValue={query} />

        <FilterChips
          query={query}
          activeType={type}
          activeTags={tags}
          availableTypes={MERCHANT_TYPES_IN_USE}
          availableTags={TAGS_IN_USE}
        />
      </div>

      <div className="grid flex-1 gap-6 lg:grid-cols-[minmax(0,1fr)_360px]">
        <section className="flex flex-col gap-3">
          <div className="flex items-baseline justify-between px-1">
            <span className="text-[13px] text-foreground-muted">
              {countLabel}
            </span>
            {hasFilters || query ? (
              <Link
                href="/buscar"
                className="text-[13px] font-semibold text-accent hover:text-accent-light"
              >
                {hasFilters ? "Limpiar filtros" : "Limpiar búsqueda"}
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
                {hasFilters
                  ? "Ningún lugar con esos filtros"
                  : `No encontramos lugares para “${query}”`}
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
