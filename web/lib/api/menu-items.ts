// Real fetch implementation for GET /api/v1/merchants/:id/menu_items
// (PLAN.md Fase 3). Unverified against a live backend in this worktree —
// see ./README.md.
//
// `price` is a decimal column, so — per the same BigDecimal-as-string
// serialization confirmed for merchants (see ./merchants.ts) — it's
// expected to come back as a JSON string here too, even though this
// specific endpoint's response shape hasn't been confirmed against real
// request specs yet (only GET /api/v1/merchants has). Parsed back to a
// number at this boundary either way, same as the merchants client.
//
// Envelope: unlike GET /api/v1/merchants, no pagination/`{ data, meta }`
// wrapper is assumed here — a merchant's menu is a bounded, small list, not
// something that needs paging. Revisit if that turns out wrong.

import type { MenuItem } from "@/lib/types";
import { apiFetch } from "./client";

interface RawMenuItem extends Omit<MenuItem, "price"> {
  price: string;
}

function parseMenuItem(raw: RawMenuItem): MenuItem {
  const price = Number(raw.price);
  return { ...raw, price: Number.isFinite(price) ? price : 0 };
}

export async function fetchMenuItemsForMerchant(
  merchantId: number,
): Promise<MenuItem[]> {
  const raw = await apiFetch<RawMenuItem[]>(
    `/merchants/${merchantId}/menu_items`,
  );
  return raw.map(parseMenuItem);
}
