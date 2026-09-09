// Trivial mock "search" over the real fixture merchant dataset.
//
// This is NOT the real natural-language search from the PRD (that needs a
// real backend/LLM). It's a proportional stand-in for this low-priority SSR
// pass: a case-insensitive substring match over name, type, tags,
// neighborhood, and the featured dish, narrowed by real `type`/`tags` filters
// — enough to make the search bar and filter chips feel real without faking
// AI understanding it doesn't have yet.

import type { Merchant, MerchantType } from "@/lib/types";
import { MERCHANT_TYPE_LABELS, TAG_LABELS } from "@/lib/mock/merchants";

export interface SearchFilters {
  /** Free-text query, matched as a substring (see haystack below). */
  query?: string;
  /** Single merchant type — a merchant only has one, so this is exclusive. */
  type?: MerchantType;
  /** Tags a merchant must have at least one of (OR within tags, AND with type/query). */
  tags?: string[];
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

    const haystack = [
      merchant.name,
      merchant.neighborhood,
      merchant.type,
      MERCHANT_TYPE_LABELS[merchant.type],
      merchant.topDish ?? "",
      ...merchant.tags,
      ...merchant.tags.map((tag) => TAG_LABELS[tag] ?? tag),
    ]
      .join(" ")
      .toLowerCase();

    return haystack.includes(normalizedQuery);
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
