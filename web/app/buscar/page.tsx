// Public, SSR search page — the only piece of the mobile app's 3 tabs this
// web platform surfaces (see PRD: web is the lowest-priority, SEO-oriented
// slice of just "Buscar"). Server Component: data, filtering, and sorting
// all happen here; the interactive shell (BuscarView) is a client island
// that receives the final, already-filtered arrays as props — see its doc
// comment for why the phone/wide split and the loadMore reveal both live
// there instead of duplicating server logic.
//
// The base query/tags filter still goes through lib/data/search (mock
// fixture dataset by default, real `GET /api/v1/merchants` once
// NEXT_PUBLIC_API_BASE_URL is set — see lib/api/README.md). `type` and
// `neighborhood` are forwarded to the same real query params (see
// Api::V1::MerchantsController#filtered_merchants); `price`/`dist`/`sort`/
// `hideVisited` are additional dimensions layered on top directly in this
// file, the same way the design reference's own `merchantsBase()` chains one
// filter after another:
// - `price` has no server-side equivalent that matches this UI's semantics —
//   the backend's `price_per_person` param finds merchants whose min/max
//   range *covers one point value* (see `Merchant.filter_by_price_per_person`
//   in the backend), while this UI offers price *bands* ("Hasta $20.000").
//   Forcing a single representative number from a band onto that point-match
//   contract would silently change what "Hasta $20.000" means, so this stays
//   an honest client-side narrowing over the already-fetched (real, not
//   mock) merchant list instead.
// - `dist`/`sort=distancia` need each merchant's distance from the visitor,
//   which the backend has no lat/lng-aware endpoint for at all — computed
//   server-side in this file instead from the `?lat=&lng=` query params
//   BuscarView syncs from the browser's geolocation (see its doc comment).
// - `hideVisited` is a cosmetic client-only gate (see its own comment below)
//   with no real per-consumer data behind it yet.

import { SearchAnalytics } from "@/components/analytics/SearchAnalytics";
import { FluidContainer } from "@/components/ui/FluidContainer";
import { BuscarView } from "@/components/features/buscar/BuscarView";
import { AiSearchResolver } from "@/components/features/buscar/AiSearchResolver";
import type { ResultMode } from "@/components/features/buscar/ResultModeToggle";
import { getDishSearchResults } from "@/lib/data/menu-items";
import { searchMerchants } from "@/lib/data/search";
import {
  getBusinessHoursForMerchant,
  getOpenStatus,
  groupBusinessHoursByDay,
} from "@/lib/data/business-hours";
import { getMockVisitCount } from "@/lib/mock/loyalty";
import { MERCHANT_TYPES_IN_USE, TAGS_IN_USE } from "@/lib/mock/merchants";
import type { Merchant, MerchantType } from "@/lib/types";
import {
  haversineDistanceKm,
  roundToOneDecimal,
  type Coordinates,
} from "@/lib/utils/distance";
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

/**
 * `?lat=`/`?lng=` -> a finite number within `[min, max]`, or `null` for
 * missing/malformed/out-of-range input — an out-of-bounds value (e.g.
 * `?lat=999`) is treated the same as an absent one rather than producing a
 * nonsensical distance.
 */
function parseCoordinateParam(raw: string, min: number, max: number): number | null {
  if (!raw) return null;
  const value = Number(raw);
  return Number.isFinite(value) && value >= min && value <= max ? value : null;
}

/**
 * Computes each merchant's real distance from `origin` server-side, using
 * the same haversine formula (lib/utils/distance.ts) the client card
 * recalculation (lib/location/use-merchant-distance.ts) uses — this is what
 * makes the "dist" filter and "sort=distancia" below actually mean something
 * instead of comparing every merchant's default `distanceKm: 0`
 * (lib/api/merchants.ts's `parseMerchant` — a request-time API layer has no
 * access to the browser's live position on its own). No-ops entirely when
 * `origin` is null (visitor hasn't activated location yet). When a merchant's
 * own coordinates fail to parse (`NaN` sentinel, see `parseCoordinate`), its
 * distance is unknown rather than zero — same criterion the client-side
 * recomputation (lib/location/use-merchant-distance.ts) uses, which returns
 * `null` for this exact case instead of defaulting to "0 km away". Since
 * `Merchant.distanceKm` is a strict `number`, `Infinity` stands in as the
 * "unknown" sentinel here: it fails any finite `dist` radius filter
 * (`Infinity <= km` is always false, so the merchant is excluded rather than
 * passing by default) and always sorts last under `sort=distancia`, without
 * widening the shared `Merchant` type.
 */
function withDistances(
  merchants: Merchant[],
  origin: Coordinates | null,
): Merchant[] {
  if (!origin) return merchants;
  return merchants.map((merchant) => {
    if (!Number.isFinite(merchant.latitude) || !Number.isFinite(merchant.longitude)) {
      return { ...merchant, distanceKm: Number.POSITIVE_INFINITY };
    }
    return {
      ...merchant,
      distanceKm: roundToOneDecimal(haversineDistanceKm(origin, merchant)),
    };
  });
}

/**
 * Real-time "abierto ahora" check for the filter sheet's "Disponibilidad"
 * row — reuses the same business-hours lookup + `getOpenStatus` derivation
 * the merchant detail page's "Abierto ahora" pill already relies on
 * (lib/hooks/use-open-status.ts), just run across a whole result set
 * server-side instead of one merchant at a time client-side. Only ever
 * called when the filter is actually active (see `applyExtraFilters`) so a
 * plain /buscar request doesn't pay for N business-hours lookups it doesn't
 * need.
 */
async function getOpenNowMerchantIds(merchants: Merchant[]): Promise<Set<number>> {
  const now = new Date();
  const openFlags = await Promise.all(
    merchants.map(async (merchant) => {
      const hours = await getBusinessHoursForMerchant(merchant.id);
      const weekHours = groupBusinessHoursByDay(hours);
      return getOpenStatus(weekHours, now).isOpen;
    }),
  );
  const ids = new Set<number>();
  merchants.forEach((merchant, index) => {
    if (openFlags[index]) ids.add(merchant.id);
  });
  return ids;
}

async function applyExtraFilters(
  merchants: Merchant[],
  params: BuscarParams,
): Promise<Merchant[]> {
  let out = merchants;

  // Real query param in API mode (see searchMerchants call below, which
  // forwards `hood` as the confirmed `neighborhood` filter) — this re-check
  // is then a harmless no-op. In mock mode it's the only place `hood`
  // narrows anything, since `lib/mock/search.ts`'s `searchMerchants` doesn't
  // understand `neighborhood` (see its doc comment).
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

  if (params.open === "now") {
    const openIds = await getOpenNowMerchantIds(out);
    out = out.filter((merchant) => openIds.has(merchant.id));
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

  // "Premios" filter row (filter-rows.ts's "premios" category) — narrows to
  // merchants with a loyalty teaser. Same UI-only-field situation as
  // `price` above: `rewardTeaser` has no backend column yet (see lib/types'
  // doc comment on it and lib/api/merchants.ts), so this is a real filter
  // against MOCK_MERCHANTS today and naturally returns nothing once
  // real-API mode is active, until the backend grows a loyalty_rules join
  // for `parseMerchant` to read instead of always defaulting to `undefined`.
  if (params.reward === "1") {
    out = out.filter((merchant) => merchant.rewardTeaser != null);
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

  // The home hero's "IA" search (HeroSearch.tsx) lands here with `?ai=<free
  // text>` instead of the usual filter params — resolving that prompt into
  // real filters needs a client-side call carrying the visitor's auth token
  // (POST /api/v1/search is protected, and this Server Component has no
  // access to the browser's localStorage-held JWT — see
  // lib/auth/token-storage.ts), so this branch skips the normal SSR
  // merchant fetch entirely and hands off to AiSearchResolver, which shows
  // the same skeleton this page's own loading.tsx uses while it resolves
  // client-side and then replaces the URL with plain `type`/`hood`/`tags`/
  // `price` params — a normal SSR render of this same page, just one
  // navigation later.
  const aiQuery = firstString(rawParams.ai);
  if (aiQuery) {
    return (
      <FluidContainer as="main" className="flex flex-1 flex-col gap-6 pt-8 pb-28">
        <AiSearchResolver query={aiQuery} presetType={firstString(rawParams.type)} />
      </FluidContainer>
    );
  }

  const rawLat = firstString(rawParams.lat);
  const rawLng = firstString(rawParams.lng);
  const parsedLat = parseCoordinateParam(rawLat, -90, 90);
  const parsedLng = parseCoordinateParam(rawLng, -180, 180);
  // Both coordinates or neither — a lone lat/lng with no pair isn't a usable
  // origin, so it's dropped from the URL entirely rather than kept half-set.
  const origin: Coordinates | null =
    parsedLat != null && parsedLng != null
      ? { latitude: parsedLat, longitude: parsedLng }
      : null;

  const current: BuscarParams = {
    q: firstString(rawParams.q),
    type: firstString(rawParams.type),
    tags: parseTags(firstString(rawParams.tags)).join(","),
    mode: firstString(rawParams.mode),
    tab: firstString(rawParams.tab) === "map" ? "map" : "",
    price: firstString(rawParams.price),
    hood: firstString(rawParams.hood),
    dist: firstString(rawParams.dist),
    open: firstString(rawParams.open) === "now" ? "now" : "",
    sort: firstString(rawParams.sort),
    hideVisited: firstString(rawParams.hideVisited) === "1" ? "1" : "",
    reward: firstString(rawParams.reward) === "1" ? "1" : "",
    lat: origin ? rawLat : "",
    lng: origin ? rawLng : "",
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
    current.open === "now" ||
    current.hideVisited === "1" ||
    current.reward === "1";

  // In Platos mode, the free-text query is a DISH name, not a merchant name
  // (see getDishSearchResults below) — passing it into searchMerchants here
  // would apply its merchant.name-only substring match (lib/mock/search.ts)
  // and narrow (or empty) the candidate list before dish-level matching ever
  // runs, so a dish-name query that doesn't also happen to match a merchant
  // name would never surface its merchant/dish at all. Omitting `query`
  // keeps the full type/tag-filtered merchant candidate set for
  // getDishSearchResults to search by dish name instead. In Lugares mode
  // (the default), `query` still narrows by merchant name here exactly as
  // before (see 0fdc167) — dishes stay unused in that mode anyway.
  const merchantNameQuery = mode === "platos" ? undefined : query;

  // Fetched without `neighborhood` so the hood dropdown always lists every
  // neighborhood available under the current type/tags/query, even while a
  // hood filter is active (see availableHoods below) — narrowing this same
  // fetch by hood would collapse the dropdown to just the selected one.
  const availabilityResults = await searchMerchants({
    query: merchantNameQuery,
    type: type ?? undefined,
    tags,
  });
  // Only re-fetched (this time with `neighborhood` forwarded as the real
  // query param) when a hood filter is actually active — otherwise it's the
  // exact same request as availabilityResults above, so there's no reason to
  // pay for a second round trip.
  const scopedResults = current.hood
    ? await searchMerchants({
        query: merchantNameQuery,
        type: type ?? undefined,
        tags,
        neighborhood: current.hood,
      })
    : availabilityResults;

  const baseResults = withDistances(scopedResults, origin);
  const merchants = await applyExtraFilters(baseResults, current);
  const availableHoods = Array.from(
    new Set(
      availabilityResults
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
          open: null,
          hideVisited: null,
          reward: null,
        })}
      />
    </FluidContainer>
  );
}
