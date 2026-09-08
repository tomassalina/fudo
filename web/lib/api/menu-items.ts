// Real fetch implementation for GET /api/v1/merchants/:id/menu_items
// (PLAN.md Fase 3). Unverified against a live backend — see ./README.md.

import type { MenuItem } from "@/lib/types";
import { apiFetch } from "./client";

export async function fetchMenuItemsForMerchant(
  merchantId: number,
): Promise<MenuItem[]> {
  return apiFetch<MenuItem[]>(`/merchants/${merchantId}/menu_items`);
}
