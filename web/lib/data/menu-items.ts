// Data-layer facade for menu items — see lib/data/merchants.ts for the
// mock/real switching rationale. `groupMenuItemsBySection` is pure
// (no I/O) and re-exported as-is from lib/mock/menu-items instead of being
// duplicated here.

import type { DishSearchResult, Merchant, MenuItem } from "@/lib/types";
import { getMenuItemsForMerchant as getMockMenuItemsForMerchant } from "@/lib/mock/menu-items";
import { isApiConfigured } from "@/lib/api/client";
import { fetchMenuItemsForMerchant } from "@/lib/api/menu-items";

export async function getMenuItemsForMerchant(
  merchantId: number,
): Promise<MenuItem[]> {
  if (!isApiConfigured()) {
    return getMockMenuItemsForMerchant(merchantId);
  }
  return fetchMenuItemsForMerchant(merchantId);
}

export { groupMenuItemsBySection } from "@/lib/mock/menu-items";

function normalize(value: string): string {
  return value
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "");
}

/**
 * Dish search for /buscar's "Platos" mode (`resModes` in the design
 * reference). There is no cross-merchant dish-search endpoint — confirmed
 * real routes are only `GET /api/v1/menu_items?merchant_id=X` (see
 * lib/api/README.md's "Endpoint coverage" table) — so this fetches each
 * candidate merchant's items through the same `getMenuItemsForMerchant`
 * facade above (mock or real, whichever `isApiConfigured()` picks) and
 * filters client-side, same pattern `fetchMerchants` already uses to page
 * through the merchant list. `merchants` should already be narrowed by the
 * page's other filters (type/tags/query) so this doesn't fan out to all ~30
 * merchants on every request.
 */
export async function getDishSearchResults(
  merchants: Merchant[],
  query: string,
): Promise<DishSearchResult[]> {
  const normalizedQuery = normalize(query.trim());
  const byMerchant = await Promise.all(
    merchants.map(async (merchant) => ({
      merchant,
      items: await getMenuItemsForMerchant(merchant.id),
    })),
  );

  const results: DishSearchResult[] = [];
  for (const { merchant, items } of byMerchant) {
    for (const item of items) {
      if (normalizedQuery) {
        const haystack = normalize(
          [item.name, item.description ?? "", item.section, merchant.name].join(
            " ",
          ),
        );
        if (!haystack.includes(normalizedQuery)) continue;
      }
      results.push({ item, merchant });
    }
  }
  return results;
}
