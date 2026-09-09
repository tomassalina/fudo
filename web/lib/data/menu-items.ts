// Data-layer facade for menu items — see lib/data/merchants.ts for the
// mock/real switching rationale. `groupMenuItemsBySection` is pure
// (no I/O) and re-exported as-is from lib/mock/menu-items instead of being
// duplicated here.

import type { MenuItem } from "@/lib/types";
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
