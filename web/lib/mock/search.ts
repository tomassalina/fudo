// Trivial mock "search" over the real fixture merchant dataset.
//
// This is NOT the real natural-language search from the PRD (that needs a
// real backend/LLM). It's a proportional stand-in for this low-priority SSR
// pass: a case-insensitive substring match over name, type, tags,
// neighborhood, and the featured dish — enough to make the search bar feel
// real without faking AI understanding it doesn't have yet.

import type { Merchant } from "@/lib/types";
import { MERCHANT_TYPE_LABELS, TAG_LABELS } from "@/lib/mock/merchants";

export function searchMerchants(
  merchants: Merchant[],
  query: string,
): Merchant[] {
  const normalized = query.trim().toLowerCase();

  if (!normalized) {
    return merchants;
  }

  return merchants.filter((merchant) => {
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

    return haystack.includes(normalized);
  });
}

/** Rotating placeholder examples for the search input, per the PRD. */
export const SEARCH_EXAMPLES = [
  "Algo picante y barato cerca mío",
  "Café tranquilo para laburar en Palermo",
  "Sushi para pedir en pareja",
  "Un lugar con buena onda para cumpleaños",
  "Hamburguesas con descuento hoy",
];

/** Quick shortcuts shown under the search bar as plain links (no JS required). */
export const QUICK_FILTER_TYPES = [
  "restaurant",
  "cafe",
  "bar",
  "pizzeria",
  "brewery",
] as const;
