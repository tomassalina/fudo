// Real fetch implementation for GET /api/v1/merchants and
// GET /api/v1/merchants/:id (PLAN.md Fase 3). Unverified against a live
// backend — see ./README.md.

import { cache } from "react";
import type { BusinessHours, Merchant } from "@/lib/types";
import { apiFetch, ApiError } from "./client";

/** Shape assumed for `GET /api/v1/merchants/:id` — see README.md's
 * "Assumption, not a confirmed contract" note on `business_hours`. */
export interface MerchantDetailResponse extends Merchant {
  business_hours?: BusinessHours[];
}

export async function fetchMerchants(): Promise<Merchant[]> {
  return apiFetch<Merchant[]>("/merchants");
}

/**
 * Wrapped in React's `cache()` so that fetching a merchant's detail and its
 * business hours in the same request-render (two separate call sites in
 * `app/restaurantes/[id]/page.tsx`: `generateMetadata` + the page itself,
 * plus the data-layer split between merchant and business-hours facades)
 * only hits the network once instead of duplicating the request.
 *
 * Returns `null` on a real 404 (merchant doesn't exist) so callers can
 * distinguish "not found" from every other failure, which should propagate
 * as an `ApiError` instead.
 */
export const fetchMerchantDetail = cache(
  async (id: number): Promise<MerchantDetailResponse | null> => {
    try {
      return await apiFetch<MerchantDetailResponse>(`/merchants/${id}`);
    } catch (error) {
      if (error instanceof ApiError && error.status === 404) {
        return null;
      }
      throw error;
    }
  },
);
