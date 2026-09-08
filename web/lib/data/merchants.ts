// Data-layer facade for merchants — the one thing page components import.
// Picks mock vs. real per `isApiConfigured()` (see lib/api/README.md for
// the hard-switch rationale) so `app/**/page.tsx` never has to know which
// backend answered it.

import type { Merchant } from "@/lib/types";
import { MOCK_MERCHANTS } from "@/lib/mock/merchants";
import { isApiConfigured } from "@/lib/api/client";
import {
  fetchMerchantDetail,
  fetchMerchants,
  type MerchantsListFilters,
} from "@/lib/api/merchants";

/**
 * `filters` only has an effect in real-API mode — `fetchMerchants` forwards
 * it to the backend's confirmed query params. Ignored for mock mode, since
 * `MOCK_MERCHANTS` carries real tags and callers (lib/data/search.ts)
 * filter it client-side instead.
 */
export async function getMerchants(
  filters?: MerchantsListFilters,
): Promise<Merchant[]> {
  if (!isApiConfigured()) {
    return MOCK_MERCHANTS;
  }
  return fetchMerchants(filters);
}

/** `null` when the merchant doesn't exist — callers should treat that as a
 * 404 (`notFound()`), not an error state. Anything else that goes wrong
 * (network failure, 5xx) throws and is left to propagate to `error.tsx`. */
export async function getMerchantById(id: number): Promise<Merchant | null> {
  if (!isApiConfigured()) {
    return MOCK_MERCHANTS.find((merchant) => merchant.id === id) ?? null;
  }
  return fetchMerchantDetail(id);
}
