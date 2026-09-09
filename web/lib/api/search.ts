// Real fetch for `POST /api/v1/search` — the Gemini-backed natural-language
// search parser (see backend/app/services/search_query_parser.rb and
// backend/app/controllers/api/v1/search_controller.rb). Protected
// (`authenticate_consumer!`, confirmed in the controller source and its
// spec's "returns 401 without authentication" case), so every call carries
// the `Authorization` header the same way visits.ts/favorites.ts do.
//
// This is the ONLY caller of this endpoint anywhere in the app —
// lib/search/resolve-ai-search.ts, used exclusively by the home hero's "IA"
// search entry point. The plain text filter on /buscar (SearchBar.tsx) never
// reaches this file or this endpoint at all; see lib/mock/search.ts's header
// comment for that separation and why it must stay that way.
//
// The `filters` field on the response is an addition made alongside this
// client (see search_controller.rb's own comment) — the endpoint originally
// returned only `data`/`meta` (matched merchants), with no way for a caller
// to know which neighborhood/type/tags/price Gemini actually derived. That
// data literally cannot be reconstructed from the embedded merchant list
// alone, and it's required to build the shareable `/buscar?type=...&hood=...`
// URL this app's AI search flow lands on.

import { apiFetch } from "./client";
import { authHeader } from "@/lib/auth/token-storage";
import type { MerchantType } from "@/lib/types";

/** Mirrors `SearchQueryParser.response_schema` / `SearchHistory#structured_output`
 * (backend/app/services/search_query_parser.rb) field-for-field. */
export interface SearchQueryFilters {
  neighborhood: string | null;
  type: MerchantType | null;
  tags: string[];
  price_per_person: number | null;
  /** "Abierto ahora" — maps onto /buscar's `open=now` param (see
   * lib/search/resolve-ai-search.ts). No real backend filter behind it yet;
   * see the backend schema's own doc comment on this field. */
  open: boolean | null;
  /** "Premio por visitas" — maps onto /buscar's `reward=1` param. Same
   * no-backend-filter-yet situation as `open` above. */
  reward: boolean | null;
}

interface RawSearchResponse {
  // Matched merchants + pagination meta are part of the real response but
  // deliberately unused here — /buscar always re-fetches its own results
  // from `filters` via the existing GET /api/v1/merchants path (see
  // lib/search/resolve-ai-search.ts), the same one every other /buscar
  // filter already goes through (price/dist/sort/hideVisited layering
  // included), instead of trusting a second, parallel result set that never
  // went through any of that.
  data: unknown[];
  meta: unknown;
  filters: SearchQueryFilters;
}

/**
 * Sends the visitor's free-text query to the real Gemini-backed parser and
 * returns the structured filters it derived. Throws `ApiError` (see
 * ./client.ts) on any non-2xx response — in particular a 401 when there is
 * no signed-in consumer (this endpoint has no anonymous/public mode) and a
 * 502 when Gemini itself is unavailable — both left for the caller to
 * degrade gracefully rather than handled here.
 */
export async function parseSearchQuery(
  query: string,
): Promise<SearchQueryFilters> {
  const response = await apiFetch<RawSearchResponse>("/search", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...authHeader(),
    },
    body: JSON.stringify({ query }),
  });
  return response.filters;
}
