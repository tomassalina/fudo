// Real fetch for `POST /api/v1/search` — the Gemini-backed natural-language
// search parser (see backend/app/services/search_query_parser.rb and
// backend/app/controllers/api/v1/search_controller.rb). Public/unauthenticated
// by product rule (AI search and /buscar are free, no account required — see
// the controller's own doc comment), so this works fully logged out. It
// still forwards `authHeader()` (a no-op `{}` when there's no token) so that
// an already-logged-in consumer's queries keep getting attributed to their
// search history server-side, same as visits.ts/favorites.ts do for their
// own (auth-required) endpoints.
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
  /** Free-text fragment naming a specific dish/ingredient or merchant that
   * doesn't map to `type`/`tags` (e.g. "milanesa", "la parrilla de
   * Borges") — maps onto /buscar's own `q` param, which /buscar's own
   * search bar matches for free (tab-aware, see
   * lib/data/menu-items.ts's `getDishSearchResults`). This parser never
   * matches it against anything itself. */
  query: string | null;
  /** Whether `query` is about a PLACE ("lugares") or a DISH ("platos") —
   * maps onto /buscar's `mode` param. */
  result_mode: "lugares" | "platos" | null;
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
 * returns the structured filters it derived. Works fully logged out — no
 * account required. Throws `ApiError` (see ./client.ts) on any non-2xx
 * response — in particular a 502 when Gemini itself is unavailable — left
 * for the caller to degrade gracefully rather than handled here.
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
