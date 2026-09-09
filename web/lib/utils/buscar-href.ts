// Shared `/buscar?...` URL builder — every filter control on the page (type
// grid, AI/tag chips, Lugares/Platos toggle, sort/price/hood/distance
// selects, "ocultar visitados") is a plain, no-JS-required link or GET form
// field that composes on top of whatever's already in the URL, per the
// existing SearchBar/FilterChips convention (see app/buscar/page.tsx). One
// shared builder keeps every control agreeing on param names and key order
// instead of each hand-rolling its own `URLSearchParams`.

/** Every filter dimension /buscar reads from the URL — see app/buscar/page.tsx's parsing. */
export interface BuscarParams {
  q: string;
  type: string;
  tags: string;
  mode: string;
  price: string;
  hood: string;
  dist: string;
  sort: string;
  hideVisited: string;
  /**
   * Visitor's live coordinates (fixed to 3 decimals, ~110m — "city-scale"
   * precision, same rationale as use-location.ts's GEOLOCATION_OPTIONS
   * comment), synced into the URL by BuscarView whenever the header's
   * "Activar ubicación" pill is on. Not a filter a person picks directly —
   * excluded from countActiveFilters below, same as q/mode/sort — but
   * app/buscar/page.tsx reads them to compute each merchant's real
   * distanceKm server-side, which the "dist" filter and "sort=distancia"
   * both depend on.
   */
  lat: string;
  lng: string;
}

export const DEFAULT_BUSCAR_PARAMS: BuscarParams = {
  q: "",
  type: "",
  tags: "",
  mode: "",
  price: "",
  hood: "",
  dist: "",
  sort: "",
  hideVisited: "",
  lat: "",
  lng: "",
};

/** Fixed key order so the resulting query string is deterministic (and testable). */
const FIELD_ORDER: (keyof BuscarParams)[] = [
  "q",
  "type",
  "tags",
  "mode",
  "price",
  "hood",
  "dist",
  "sort",
  "hideVisited",
  "lat",
  "lng",
];

/**
 * Builds a `/buscar?...` href from the current params plus overrides —
 * `null`/`""` in an override clears that field instead of setting it.
 */
export function buscarHref(
  current: BuscarParams,
  overrides: Partial<Record<keyof BuscarParams, string | null>> = {},
): string {
  const params = new URLSearchParams();

  for (const key of FIELD_ORDER) {
    const hasOverride = Object.prototype.hasOwnProperty.call(overrides, key);
    const value = hasOverride ? overrides[key] : current[key];
    if (value) params.set(key, value);
  }

  const qs = params.toString();
  return qs ? `/buscar?${qs}` : "/buscar";
}

/** Number of active filters shown as the badge on the phone "tune" button and
 * the sidebar's "Filtros" header — mirrors `filterCount`/`hasFilters` in the
 * design, counting `type`, each tag, `price`, `hood`, `dist`, and
 * `hideVisited` as one each. `q`, `mode`, and `sort` are search text/display
 * choices, not filters, so they're excluded — same distinction the design
 * itself draws (`hasFilters` never reacts to the query or sort order).
 * `lat`/`lng` are position data synced automatically from the browser, not a
 * filter the visitor picks, so they're excluded too. */
export function countActiveFilters(current: BuscarParams): number {
  let count = 0;
  if (current.type) count += 1;
  if (current.tags) count += current.tags.split(",").filter(Boolean).length;
  if (current.price) count += 1;
  if (current.hood) count += 1;
  if (current.dist) count += 1;
  if (current.hideVisited === "1") count += 1;
  return count;
}
