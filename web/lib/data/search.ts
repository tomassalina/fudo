// Data-layer facade for search — see lib/data/merchants.ts for the
// mock/real switching rationale.
//
// `POST /api/v1/search` (the real natural-language endpoint PLAN.md
// documents) turned out, confirmed against the live backend's swagger
// spec and a live 401 response, to require `bearer_auth` — a logged-in
// consumer. This app is intentionally public/unauthenticated (see
// lib/api/README.md's "Out of scope: auth" section), so that endpoint is
// unusable here and is NOT called.
//
// Instead, both mock and real modes go through the same path: fetch the
// merchant list (mock or real, via getMerchants()) and run it through the
// exact same client-side type/tags/substring filtering
// (lib/mock/search.ts's searchMerchants) that already powers this page
// today. This is not a regression from what real natural-language search
// would have done — this app never had real NLP search; the "AI"
// filtering was always a documented stand-in (see lib/mock/search.ts's
// own header comment), so the ceiling here doesn't change, only the data
// source under it does.
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
// app never calls the real NLP search endpoint, see lib/api/README.md's
// point 4) so it stays client-side in both modes.

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
