// Data-layer facade for search — see lib/data/merchants.ts for the
// mock/real switching rationale.
//
// Note the shape change from the underlying mock helper: `lib/mock/search`'s
// `searchMerchants(merchants, filters)` filters a caller-provided array
// client-side. The real `POST /api/v1/search` endpoint searches server-side
// over the whole dataset instead, so there's no "array of merchants to
// search" for a caller to provide. This facade takes just `filters` and
// owns fetching the candidate set itself (`getMerchants()` in the mock
// branch), so `app/buscar/page.tsx` doesn't need to know which shape the
// active backend expects.

import type { Merchant } from "@/lib/types";
import type { SearchFilters } from "@/lib/mock/search";
import { searchMerchants as searchMockMerchants } from "@/lib/mock/search";
import { isApiConfigured } from "@/lib/api/client";
import { fetchSearchMerchants } from "@/lib/api/search";
import { getMerchants } from "@/lib/data/merchants";

export type { SearchFilters } from "@/lib/mock/search";
export { SEARCH_EXAMPLES } from "@/lib/mock/search";

export async function searchMerchants(
  filters: SearchFilters,
): Promise<Merchant[]> {
  if (!isApiConfigured()) {
    const merchants = await getMerchants();
    return searchMockMerchants(merchants, filters);
  }
  return fetchSearchMerchants(filters);
}
