// The /buscar text search bar's (SearchBar.tsx) filtering logic — a plain,
// client-side, case-insensitive substring match against `merchant.name`
// ONLY, narrowed by the real `type`/`tags` chip filters. This is
// deliberately narrow: it's the free-text search box, not the home hero's
// "IA" search — that one is a different feature entirely, resolved via the
// real Gemini-backed parser (POST /api/v1/search, see lib/api/search.ts and
// lib/search/resolve-ai-search.ts) into structured filters instead of a
// substring match. This function never calls that endpoint and never will:
// it's the honest, simple "find it by its name" behavior /buscar's search
// bar promises, nothing more (see its placeholder/aria-label). Matching
// against neighborhood/type/tags/topDish here too — the previous behavior —
// blurred that line: it made the plain text box quietly behave like a
// keyword search over everything, indistinguishable from what the AI search
// was supposed to be doing instead.

import type { Merchant, MerchantType } from "@/lib/types";

export interface SearchFilters {
  /** Free-text query, matched as a substring against `merchant.name` only
   * (see the haystack below) — NOT neighborhood, type, tags, or dish. */
  query?: string;
  /** Single merchant type — a merchant only has one, so this is exclusive. */
  type?: MerchantType;
  /** Tags a merchant must have at least one of (OR within tags, AND with type/query). */
  tags?: string[];
  /**
   * Exact neighborhood match. NOT applied by this function — accepted here
   * only so `lib/data/search.ts` can pass one `SearchFilters` object through
   * both branches: in real-API mode it's forwarded as the confirmed
   * `neighborhood` query param (see lib/api/merchants.ts) before this
   * function ever runs; in mock mode it's ignored here and the `hood` filter
   * in app/buscar/page.tsx's `applyExtraFilters` does the narrowing instead.
   */
  neighborhood?: string;
}

export function searchMerchants(
  merchants: Merchant[],
  filters: SearchFilters,
): Merchant[] {
  const normalizedQuery = filters.query?.trim().toLowerCase() ?? "";
  const tags = filters.tags ?? [];

  return merchants.filter((merchant) => {
    if (filters.type && merchant.type !== filters.type) {
      return false;
    }

    if (tags.length > 0 && !tags.some((tag) => merchant.tags.includes(tag))) {
      return false;
    }

    if (!normalizedQuery) {
      return true;
    }

    return merchant.name.toLowerCase().includes(normalizedQuery);
  });
}

/**
 * Rotating placeholder examples for the search input — the exact `HINTS`
 * array from the design reference (`docs/design-reference/Fudo App.dc.html`),
 * not an approximation. Shared by the home hero's typewriter animation and
 * the /buscar search bar's placeholder rotation, so both stay in sync with
 * the same design-sourced copy.
 */
export const SEARCH_EXAMPLES = [
  "Algo picante y barato cerca mío",
  "Café tranquilo para laburar en Palermo",
  "Parrilla para ir con amigos esta noche",
  "Opción sin TACC para almorzar",
  "Sushi que no sea carísimo",
];
