// Data-layer facade for merchants — the one thing page components import.
// Picks mock vs. real per `isApiConfigured()` (see lib/api/README.md for
// the hard-switch rationale) so `app/**/page.tsx` never has to know which
// backend answered it.

import type { Merchant } from "@/lib/types";
import { MOCK_MERCHANTS } from "@/lib/mock/merchants";
import { isApiConfigured } from "@/lib/api/client";
import { fetchMerchantDetail, fetchMerchants } from "@/lib/api/merchants";

export async function getMerchants(): Promise<Merchant[]> {
  if (!isApiConfigured()) {
    return MOCK_MERCHANTS;
  }
  return fetchMerchants();
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
