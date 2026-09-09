// Shared "price per person" band definitions — the fixed set /buscar's own
// price filter offers (see components/features/buscar/filter-rows.ts's
// PRICE_OPTIONS, which derives its option list from PRICE_BANDS below) and
// the target shape lib/search/resolve-ai-search.ts maps Gemini's single
// `price_per_person` point estimate onto, since the `price` URL param this
// app understands is always one of these three bands, never an arbitrary
// point value — there is no server-side point-price filter this UI's price
// *bands* map onto (see app/buscar/page.tsx's own comment on `price`).

export interface PriceBand {
  value: string;
  label: string;
  min: number;
  max: number;
}

export const PRICE_BANDS: PriceBand[] = [
  { value: "0-20000", label: "Hasta $20.000", min: 0, max: 20000 },
  { value: "20000-40000", label: "$20.000 – $40.000", min: 20000, max: 40000 },
  { value: "40000-999999999", label: "Más de $40.000", min: 40000, max: 999999999 },
];

/**
 * Maps a point price estimate (e.g. Gemini's `price_per_person`, see
 * lib/api/search.ts's `SearchQueryFilters`) onto the band that contains it,
 * or `null` for "no estimate" (nothing to filter by). A value below the
 * first band's floor still maps to the first band (an unusually cheap
 * estimate is still "hasta $20.000"); above the last band's ceiling maps to
 * the last, open-ended band.
 */
export function priceBandForAmount(amount: number | null): string | null {
  if (amount == null) return null;
  const band = PRICE_BANDS.find((b) => amount >= b.min && amount <= b.max);
  return band?.value ?? PRICE_BANDS[PRICE_BANDS.length - 1].value;
}
