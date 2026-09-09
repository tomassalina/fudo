// Public, SSR search page — the only piece of the mobile app's 3 tabs this
// web platform surfaces (see PRD: web is the lowest-priority, SEO-oriented
// slice of just "Buscar"). Server Component: data, filtering, and sorting
// all happen here; the interactive shell (BuscarView) is a client island
// that receives the final, already-filtered arrays as props — see its doc
// comment for why the phone/wide split and the loadMore reveal both live
// there instead of duplicating server logic.
//
// The base query/type/tags filter still goes through lib/data/search (mock
// fixture dataset by default, real `POST /api/v1/search`'s equivalent
// client-side re-filter once NEXT_PUBLIC_API_BASE_URL is set — see
// lib/api/README.md). price/hood/dist/sort/hideVisited are additional
// dimensions layered on top directly in this file, the same way the design
// reference's own `merchantsBase()` chains one filter after another — they
// don't have a confirmed server-side equivalent, so narrowing the
// already-fetched array here is the honest option instead of inventing an
// API param.

import { SearchAnalytics } from "@/components/analytics/SearchAnalytics";
import { FluidContainer } from "@/components/ui/FluidContainer";
import { Header } from "@/components/layout/Header";
import { BuscarView } from "@/components/features/buscar/BuscarView";
import type { ResultMode } from "@/components/features/buscar/ResultModeToggle";
import { getDishSearchResults } from "@/lib/data/menu-items";
import { searchMerchants } from "@/lib/data/search";
import { getMockVisitCount } from "@/lib/mock/loyalty";
import { MERCHANT_TYPES_IN_USE, TAGS_IN_USE } from "@/lib/mock/merchants";
import type { Merchant, MerchantType } from "@/lib/types";
import type { BuscarParams } from "@/lib/utils/buscar-href";
import { buscarHref } from "@/lib/utils/buscar-href";

function firstString(raw: string | string[] | undefined): string {
  return typeof raw === "string" ? raw : "";
}

function parseType(raw: string): MerchantType | null {
  return (MERCHANT_TYPES_IN_USE as string[]).includes(raw)
    ? (raw as MerchantType)
    : null;
}

function parseTags(raw: string): string[] {
  const requested = raw
    .split(",")
    .map((tag) => tag.trim())
    .filter(Boolean);
  // Keep only real, filterable tags — an unknown value in the URL just gets
  // dropped instead of silently zeroing out the results.
  return TAGS_IN_USE.filter((tag) => requested.includes(tag));
}

function parseMode(raw: string): ResultMode {
  return raw === "platos" ? "platos" : "lugares";
}

/** "min-max" -> [min, max], both inclusive. Malformed values fall back to no bound. */
function parsePriceRange(raw: string): [number, number] | null {
  const match = /^(\d+)-(\d+)$/.exec(raw);
  if (!match) return null;
  return [Number(match[1]), Number(match[2])];
}

function applyExtraFilters(
  merchants: Merchant[],
  params: BuscarParams,
): Merchant[] {
  let out = merchants;

  if (params.hood) {
    out = out.filter((merchant) => merchant.neighborhood === params.hood);
  }

  const priceRange = params.price ? parsePriceRange(params.price) : null;
  if (priceRange) {
    const [min, max] = priceRange;
    out = out.filter((merchant) => {
      const price = merchant.price_per_person_min;
      return price != null && price >= min && price <= max;
    });
  }

  if (params.dist) {
    const km = Number(params.dist);
    if (Number.isFinite(km)) {
      out = out.filter((merchant) => merchant.distanceKm <= km);
    }
  }

  // Cosmetic-only gate: the checkbox that sets this param is only rendered
  // client-side once useSession() reports isAuthenticated (see
  // FilterFields.tsx) — a Server Component can't read that hook (it's a
  // "use client" module), and there's no real per-user data at stake here
  // either way, since "visited" is the same deterministic mock derivation
  // getMockVisitCount always returns (see lib/mock/loyalty.ts), not a real
  // per-consumer record. Manually appending `?hideVisited=1` as a
  // logged-out visitor just previews the same filter, nothing private leaks.
  if (params.hideVisited === "1") {
    out = out.filter((merchant) => getMockVisitCount(merchant) === 0);
  }

  if (params.sort === "distancia") {
    out = [...out].sort((a, b) => a.distanceKm - b.distanceKm);
  } else if (params.sort === "precio") {
    out = [...out].sort((a, b) => {
      const priceA = a.price_per_person_min ?? Number.POSITIVE_INFINITY;
      const priceB = b.price_per_person_min ?? Number.POSITIVE_INFINITY;
      return priceA - priceB;
    });
  }

  return out;
}

export default async function BuscarPage({
  searchParams,
}: PageProps<"/buscar">) {
  const rawParams = await searchParams;
  const current: BuscarParams = {
    q: firstString(rawParams.q),
    type: firstString(rawParams.type),
    tags: parseTags(firstString(rawParams.tags)).join(","),
    mode: firstString(rawParams.mode),
    price: firstString(rawParams.price),
    hood: firstString(rawParams.hood),
    dist: firstString(rawParams.dist),
    sort: firstString(rawParams.sort),
    hideVisited: firstString(rawParams.hideVisited) === "1" ? "1" : "",
  };

  const query = current.q;
  const type = parseType(current.type);
  const tags = current.tags ? current.tags.split(",") : [];
  const mode = parseMode(current.mode);
  const hasFilters =
    type !== null ||
    tags.length > 0 ||
    Boolean(current.price) ||
    Boolean(current.hood) ||
    Boolean(current.dist) ||
    current.hideVisited === "1";

  const baseResults = await searchMerchants({
    query,
    type: type ?? undefined,
    tags,
  });
  const merchants = applyExtraFilters(baseResults, current);
  const availableHoods = Array.from(
    new Set(
      baseResults
        .map((merchant) => merchant.neighborhood)
        .filter((hood): hood is string => Boolean(hood)),
    ),
  ).sort((a, b) => a.localeCompare(b, "es-AR"));

  const dishes =
    mode === "platos" ? await getDishSearchResults(merchants, query) : [];

  const resultCount = mode === "platos" ? dishes.length : merchants.length;
  const countLabel =
    resultCount === 1
      ? mode === "platos"
        ? "1 plato encontrado"
        : "1 lugar encontrado"
      : mode === "platos"
        ? `${resultCount} platos encontrados`
        : `${resultCount} lugares encontrados`;

  const emptyTitle =
    mode === "platos"
      ? hasFilters || query
        ? "Ningún plato con esos filtros"
        : "No encontramos platos para tu búsqueda"
      : hasFilters
        ? "Ningún lugar con esos filtros"
        : `No encontramos lugares para “${query}”`;

  return (
    <FluidContainer as="main" className="flex flex-1 flex-col gap-6 pt-8 pb-28">
      <Header />
      <SearchAnalytics
        hasQuery={query.length > 0}
        queryText={query}
        filterTypes={type ? [type] : []}
        filterTags={tags}
        resultCount={resultCount}
      />

      <BuscarView
        current={current}
        query={query}
        activeType={type}
        activeTags={tags}
        availableTypes={MERCHANT_TYPES_IN_USE}
        availableTags={TAGS_IN_USE}
        availableHoods={availableHoods}
        mode={mode}
        merchants={merchants}
        dishes={dishes}
        countLabel={countLabel}
        emptyTitle={emptyTitle}
        clearHref={buscarHref(current, {
          type: null,
          tags: null,
          price: null,
          hood: null,
          dist: null,
          hideVisited: null,
        })}
      />
    </FluidContainer>
  );
}
