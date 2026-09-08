// Real fetch implementation for POST /api/v1/search (PLAN.md Fase 3).
// Unverified against a live backend — see ./README.md for the assumption
// this makes about request shape (type/tags alongside the documented
// free-text `query`).

import type { Merchant, MerchantType } from "@/lib/types";
import { apiFetch } from "./client";

export interface RemoteSearchFilters {
  query?: string;
  type?: MerchantType;
  tags?: string[];
}

export async function fetchSearchMerchants(
  filters: RemoteSearchFilters,
): Promise<Merchant[]> {
  return apiFetch<Merchant[]>("/search", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      query: filters.query ?? "",
      type: filters.type,
      tags: filters.tags,
    }),
  });
}
