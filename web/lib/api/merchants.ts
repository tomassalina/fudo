// Real fetch implementation for GET /api/v1/merchants and
// GET /api/v1/merchants/:id (PLAN.md Fase 3). Unverified against a live
// backend in this worktree — see ./README.md.
//
// Response shape for GET /api/v1/merchants confirmed by the backend track
// (399 passing request specs): a paginated `{ data, meta }` envelope, and
// decimal columns (price_per_person_min/max, latitude, longitude) come
// back as JSON strings, not numbers — that's how Rails serializes
// BigDecimal by default. Parsed back to numbers here, at the API boundary,
// so nothing downstream (lib/data, page components) needs to care.

import { cache } from "react";
import type { BusinessHours, Merchant } from "@/lib/types";
import { apiFetch, ApiError } from "./client";

/** Wire shape for a merchant: same as `Merchant`, except decimal columns
 * are strings, and the UI-only derived fields (`tags`, `distanceKm`, etc. —
 * see lib/types' doc comments) aren't confirmed to exist on the real
 * serializer yet, so they're optional here and defaulted in `parseMerchant`. */
interface RawMerchant
  extends Omit<
    Merchant,
    | "price_per_person_min"
    | "price_per_person_max"
    | "latitude"
    | "longitude"
    | "tags"
    | "distanceKm"
  > {
  price_per_person_min: string | null;
  price_per_person_max: string | null;
  latitude: string;
  longitude: string;
  tags?: string[];
  distanceKm?: number;
}

interface MerchantsListResponse {
  data: RawMerchant[];
  meta: {
    current_page: number;
    total_pages: number;
    total_count: number;
    per_page: number;
  };
}

interface RawMerchantDetail extends RawMerchant {
  business_hours?: BusinessHours[];
}

/** Shape assumed for `GET /api/v1/merchants/:id` — see README.md's
 * "Assumption, not a confirmed contract" note on `business_hours` (only
 * the list endpoint's shape above is confirmed so far). */
export interface MerchantDetailResponse extends Merchant {
  business_hours?: BusinessHours[];
}

function parseDecimal(value: string | null | undefined): number | undefined {
  if (value == null) return undefined;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function parseMerchant(raw: RawMerchant): Merchant {
  return {
    ...raw,
    price_per_person_min: parseDecimal(raw.price_per_person_min),
    price_per_person_max: parseDecimal(raw.price_per_person_max),
    // latitude/longitude are NOT NULL in the schema, unlike the price pair.
    latitude: parseDecimal(raw.latitude) ?? 0,
    longitude: parseDecimal(raw.longitude) ?? 0,
    tags: raw.tags ?? [],
    distanceKm: raw.distanceKm ?? 0,
  };
}

// Sanity bound on the pagination loop below — this MVP's seeded dataset is
// ~30 merchants, so this is generous headroom, not a real limit.
const MAX_PAGES = 20;

export async function fetchMerchants(): Promise<Merchant[]> {
  const merchants: Merchant[] = [];
  let page = 1;

  for (;;) {
    const response = await apiFetch<MerchantsListResponse>(
      `/merchants?page=${page}&per_page=100`,
    );
    merchants.push(...response.data.map(parseMerchant));

    if (page >= response.meta.total_pages || page >= MAX_PAGES) {
      break;
    }
    page += 1;
  }

  return merchants;
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
      const raw = await apiFetch<RawMerchantDetail>(`/merchants/${id}`);
      return { ...parseMerchant(raw), business_hours: raw.business_hours };
    } catch (error) {
      if (error instanceof ApiError && error.status === 404) {
        return null;
      }
      throw error;
    }
  },
);

// Re-exported so lib/api/search.ts can normalize search results (also
// merchants, presumably subject to the same BigDecimal-as-string
// serialization) without duplicating this parsing logic.
export { parseMerchant };
export type { RawMerchant };
