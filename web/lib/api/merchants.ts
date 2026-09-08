// Real fetch implementation for GET /api/v1/merchants and
// GET /api/v1/merchants/:id (PLAN.md Fase 3).
//
// Verified against the live backend (localhost:3000, running but not yet
// merged to main — see ./README.md's "Live verification" section for what
// was actually checked and when). Contract confirmed via curl and the
// live /api-docs/v1/swagger.yaml, not just PLAN.md's prose description.

import { cache } from "react";
import type { BusinessHours, Merchant } from "@/lib/types";
import { apiFetch, ApiError } from "./client";

/**
 * Wire shape for a merchant. Confirmed against the live swagger spec that
 * `GET /api/v1/merchants` (list) and `GET /api/v1/merchants/:id` (detail)
 * return *different* subsets of these fields:
 *
 * - List: only `id, name, type, city, latitude, longitude` are guaranteed;
 *   `neighborhood, price_per_person_min/max, cover_image_url` are present
 *   but nullable. `address`, `state`, `country`, `whatsapp_number`,
 *   `delivery_url`, `tags` are NOT returned by the list endpoint at all.
 * - Detail: includes all of the above, confirmed by curl.
 *
 * Neither endpoint returns `topDish`, `rewardTeaser`, or `distanceKm` —
 * those are UI-only derived fields with no backend column (see lib/types'
 * doc comments on `Merchant`), so they're always defaulted below
 * regardless of which endpoint answered.
 *
 * `parseMerchant` treats every field but the list's guaranteed five as
 * optional and defaults what's missing, so it works for both shapes.
 */
export interface RawMerchant {
  id: number;
  name: string;
  type: Merchant["type"];
  city: string;
  latitude: string;
  longitude: string;
  neighborhood?: string | null;
  price_per_person_min?: string | null;
  price_per_person_max?: string | null;
  cover_image_url?: string | null;
  address?: string;
  country?: string;
  state?: string;
  whatsapp_number?: string | null;
  delivery_url?: string | null;
  tags?: string[];
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

/** `opens_at`/`closes_at` come back as full ISO 8601 timestamps on an
 * arbitrary fixed date (e.g. `"2000-01-01T15:30:00.000Z"`), not the
 * `"HH:MM:SS"` string lib/types documents and lib/mock's formatting
 * helpers (`formatHm` et al.) assume — confirmed by curl. This is Rails
 * serializing a `time`-only column as a full timestamp, not a timezone
 * conversion — per PLAN.md ("ninguna columna/lógica de timezone"), the
 * whole project has no timezone logic anywhere, so the fix is to read the
 * HH:MM:SS off the string as literal wall-clock digits, not to convert
 * between zones. */
interface RawBusinessHours extends Omit<BusinessHours, "opens_at" | "closes_at"> {
  opens_at: string | null;
  closes_at: string | null;
}

interface RawMerchantDetail extends RawMerchant {
  business_hours?: RawBusinessHours[];
}

export interface MerchantDetailResponse extends Merchant {
  business_hours?: BusinessHours[];
}

export function parseDecimal(value: string | null | undefined): number | undefined {
  if (value == null) return undefined;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

/**
 * Latitude/longitude specifically must never silently fall back to `0` —
 * `(0, 0)` is a real place (off the coast of West Africa), so a defaulted
 * `?? 0` would plot a fake-valid map marker there instead of surfacing that
 * the backend sent something unparseable. `NaN` is used as the "invalid"
 * sentinel instead: it keeps `Merchant.latitude`/`longitude` as plain
 * `number` (no type change), and every real consumer (LeafletMap's
 * markers, the merchant-detail JSON-LD `geo`) can — and does — check
 * `Number.isFinite` before treating it as a real coordinate. This is
 * intentionally narrower than `parseDecimal`'s other callers
 * (price_per_person_min/max): `0` is a legitimate value for those, so they
 * keep using `undefined` (hide the field), not this NaN-sentinel pattern.
 */
export function parseCoordinate(
  value: string,
  field: "latitude" | "longitude",
  merchantId: number,
): number {
  const parsed = parseDecimal(value);
  if (parsed === undefined) {
    console.warn(
      `Merchant ${merchantId}: unparseable ${field} value ${JSON.stringify(
        value,
      )} from the API — excluding it from map markers instead of ` +
        "defaulting to 0 (which would silently place a fake marker at (0, 0)).",
    );
    return NaN;
  }
  return parsed;
}

function parseTimeOfDay(value: string | null): string | null {
  if (value == null) return null;
  const match = /T(\d{2}:\d{2}:\d{2})/.exec(value);
  return match ? match[1] : null;
}

function parseBusinessHours(raw: RawBusinessHours): BusinessHours {
  return {
    ...raw,
    opens_at: parseTimeOfDay(raw.opens_at),
    closes_at: parseTimeOfDay(raw.closes_at),
  };
}

export function parseMerchant(raw: RawMerchant): Merchant {
  return {
    id: raw.id,
    name: raw.name,
    type: raw.type,
    // Confirmed absent from the list endpoint — defaulted to "" rather
    // than left undefined, since Merchant declares these non-optional.
    // Real value is only available from the detail endpoint.
    address: raw.address ?? "",
    country: raw.country ?? "Argentina",
    state: raw.state ?? "",
    neighborhood: raw.neighborhood ?? undefined,
    city: raw.city,
    latitude: parseCoordinate(raw.latitude, "latitude", raw.id),
    longitude: parseCoordinate(raw.longitude, "longitude", raw.id),
    cover_image_url: raw.cover_image_url ?? undefined,
    whatsapp_number: raw.whatsapp_number ?? undefined,
    delivery_url: raw.delivery_url ?? undefined,
    price_per_person_min: parseDecimal(raw.price_per_person_min),
    price_per_person_max: parseDecimal(raw.price_per_person_max),
    tags: raw.tags ?? [],
    // No backend equivalent at all (UI-only derived) — see lib/types.
    topDish: undefined,
    rewardTeaser: undefined,
    distanceKm: 0,
  };
}

// Sanity bound on the pagination loop below — this MVP's seeded dataset is
// ~30 merchants, so this is generous headroom, not a real limit.
const MAX_PAGES = 20;

export interface MerchantsListFilters {
  /**
   * Forwarded as the confirmed `tags` query param (comma-separated tag
   * names, e.g. `?tags=vegano,sin_tacc` — confirmed via the live
   * `/api-docs/v1/swagger.yaml`). Must be filtered server-side: the list
   * response never echoes `tags` back (see `RawMerchant`/`parseMerchant`
   * above), so a client-side `tags.some(...)` check is always false against
   * real merchants.
   */
  tags?: string[];
}

export async function fetchMerchants(
  filters?: MerchantsListFilters,
): Promise<Merchant[]> {
  const merchants: Merchant[] = [];
  let page = 1;
  const tags = filters?.tags ?? [];
  const tagsParam =
    tags.length > 0
      ? `&tags=${tags.map(encodeURIComponent).join(",")}`
      : "";

  for (;;) {
    const response = await apiFetch<MerchantsListResponse>(
      `/merchants?page=${page}&per_page=100${tagsParam}`,
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
      return {
        ...parseMerchant(raw),
        business_hours: raw.business_hours?.map(parseBusinessHours),
      };
    } catch (error) {
      if (error instanceof ApiError && error.status === 404) {
        return null;
      }
      throw error;
    }
  },
);
