// Real fetch implementation for POST /api/v1/search (PLAN.md Fase 3).
// Unverified against a live backend — see ./README.md for the assumption
// this makes about request shape (type/tags alongside the documented
// free-text `query`).

import type { MerchantType, Merchant } from "@/lib/types";
import { apiFetch } from "./client";
import { parseMerchant, type RawMerchant } from "./merchants";

export interface RemoteSearchFilters {
  query?: string;
  type?: MerchantType;
  tags?: string[];
}

export async function fetchSearchMerchants(
  filters: RemoteSearchFilters,
): Promise<Merchant[]> {
  // Search results are merchants, so the same BigDecimal-as-string
  // serialization confirmed for GET /api/v1/merchants applies here too —
  // normalized through the same parseMerchant used there.
  const raw = await apiFetch<RawMerchant[]>("/search", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      query: filters.query ?? "",
      type: filters.type,
      tags: filters.tags,
    }),
  });
  return raw.map(parseMerchant);
}
