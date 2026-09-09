// Data-layer facade for the /buscar text search bar (SearchBar.tsx) — see
// lib/data/merchants.ts for the mock/real switching rationale. This is
// deliberately NOT the home hero's "IA" search: that flow calls the real
// `POST /api/v1/search` Gemini parser directly (lib/api/search.ts,
// lib/search/resolve-ai-search.ts, mounted via AiSearchResolver.tsx) and
// never touches this file — this module is only for the plain text field,
// which stays a simple client-side match against `merchant.name` in both
// modes (see lib/mock/search.ts's header comment for why that scope is
// deliberate, not a limitation).
//
// Both mock and real modes go through the same path: fetch the merchant
// list (mock or real, via getMerchants()) and run it through the exact
// same client-side type/tags/name-substring filtering (lib/mock/search.ts's
// searchMerchants) that already powers this page today.
//
// GET /api/v1/merchants confirms server-side `neighborhood`/`type`/`tags`
// query filters (see Api::V1::MerchantsController#filtered_merchants and
// lib/api/README.md) — all three are forwarded to `getMerchants()` below in
// real-API mode instead of narrowing the already-fetched array client-side.
// `tags` specifically MUST be forwarded server-side: the list response
// never echoes `tags` back (every real merchant parses to `tags: []`, see
// lib/api/merchants.ts), so filtering tags client-side via
// lib/mock/search.ts's `tags.some(...)` is always false against real data —
// clicking any tag chip on /buscar silently zeroed out all results. `type`
// doesn't have that problem (the list response always includes the real
// `type`), so `filterMerchants` below still re-checks it — a harmless no-op
// once the backend has already narrowed by it, and the only path that
// applies it at all in mock mode. `query` has no server equivalent (this
// module never calls the Gemini-backed search endpoint — see this file's
// own header comment) so it stays client-side, name-only, in both modes.

import type { Merchant } from "@/lib/types";
import type { SearchFilters } from "@/lib/mock/search";
import { searchMerchants as filterMerchants } from "@/lib/mock/search";
import { getMerchants } from "@/lib/data/merchants";
import { isApiConfigured } from "@/lib/api/client";

export type { SearchFilters } from "@/lib/mock/search";
export { SEARCH_EXAMPLES } from "@/lib/mock/search";

export async function searchMerchants(
  filters: SearchFilters,
): Promise<Merchant[]> {
  if (isApiConfigured()) {
    const merchants = await getMerchants({
      tags: filters.tags,
      type: filters.type,
      neighborhood: filters.neighborhood,
    });
    // `tags`/`type`/`neighborhood` already applied server-side above —
    // re-filtering by `type` here is a harmless no-op (see file header);
    // re-filtering by `tags` would zero every result (every real merchant's
    // `tags` field is always `[]`), so it's deliberately not passed again.
    return filterMerchants(merchants, {
      query: filters.query,
      type: filters.type,
    });
  }

  // Mock mode: mock merchants carry real tags, so keep filtering
  // everything client-side exactly as before. `neighborhood` isn't
  // understood by `filterMerchants` — app/buscar/page.tsx's
  // `applyExtraFilters` narrows by `hood` afterwards for this mode.
  const merchants = await getMerchants();
  return filterMerchants(merchants, filters);
}
