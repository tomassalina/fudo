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
// GET /api/v1/merchants does confirm server-side `type`/`tags` query
// filters (see lib/api/README.md), which would save fetching the full
// list — not wired up here for the same reason merchant-list filtering
// wasn't: the dataset is ~30 rows, and there's no free-text equivalent on
// that endpoint anyway, so the client-side filter is still needed for the
// `query` part regardless.

import type { Merchant } from "@/lib/types";
import type { SearchFilters } from "@/lib/mock/search";
import { searchMerchants as filterMerchants } from "@/lib/mock/search";
import { getMerchants } from "@/lib/data/merchants";

export type { SearchFilters } from "@/lib/mock/search";
export { SEARCH_EXAMPLES } from "@/lib/mock/search";

export async function searchMerchants(
  filters: SearchFilters,
): Promise<Merchant[]> {
  const merchants = await getMerchants();
  return filterMerchants(merchants, filters);
}
