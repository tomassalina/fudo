// Resolves the home hero's free-text "IA" search prompt into the real
// filters /buscar understands, via the backend's Gemini-backed parser. See
// components/features/buscar/AiSearchResolver.tsx (the only caller) for the
// full flow and lib/api/search.ts for the actual `POST /api/v1/search` call.

import { isApiConfigured, ApiError } from "@/lib/api/client";
import { parseSearchQuery } from "@/lib/api/search";
import { priceBandForAmount } from "@/lib/utils/price-bands";

export interface ResolvedAiFilters {
  type: string | null;
  neighborhood: string | null;
  tags: string[];
  /** Already mapped to one of PRICE_BANDS's `value`s (lib/utils/price-bands.ts)
   * — never a raw point price, since that's not a shape /buscar's `price`
   * URL param understands. */
  priceBand: string | null;
  /** Already mapped to /buscar's `open` param shape: "now" or null — never
   * a raw boolean, since that's not what the URL param understands (and
   * there's no real "explicitly not open" value the UI can express). */
  open: "now" | null;
  /** Already mapped to /buscar's `reward` param shape: "1" or null. */
  reward: "1" | null;
  /** The free-text dish/merchant fragment Gemini extracted, straight
   * through to /buscar's own `q` param — /buscar's own search bar (tab-
   * aware, see lib/data/menu-items.ts's `getDishSearchResults`) does the
   * actual name matching, never this resolver. `null` when Gemini found
   * nothing beyond the other structured fields. */
  q: string | null;
  /** Already mapped to /buscar's `mode` param shape: "platos" or null —
   * never the literal "lugares", since that's the default/absence of the
   * param (same convention as ResultModeToggle.tsx's own href builder). */
  mode: "platos" | null;
}

/**
 * Calls the real backend and maps its response onto this app's own filter
 * vocabulary. Throws whenever a real filter set can't be produced — mock/
 * local mode (no `NEXT_PUBLIC_API_BASE_URL`) included, since Gemini's call
 * only exists server-side (design.md Decision 8: "Nunca se llama directo
 * desde el cliente") and this app's mock layer has no natural-language
 * equivalent to stand in for it (see lib/mock/search.ts's header comment) —
 * unlike merchants/menu-items, there is no mock branch here at all. Callers
 * (AiSearchResolver) are expected to catch this and degrade to a plain
 * name-only search instead of surfacing it as a hard error.
 */
export async function resolveAiSearchFilters(
  query: string,
): Promise<ResolvedAiFilters> {
  if (!isApiConfigured()) {
    throw new ApiError("AI search requires a configured backend");
  }

  const filters = await parseSearchQuery(query);
  return {
    type: filters.type,
    neighborhood: filters.neighborhood,
    tags: filters.tags,
    priceBand: priceBandForAmount(filters.price_per_person),
    open: filters.open === true ? "now" : null,
    reward: filters.reward === true ? "1" : null,
    q: filters.query || null,
    mode: filters.result_mode === "platos" ? "platos" : null,
  };
}
