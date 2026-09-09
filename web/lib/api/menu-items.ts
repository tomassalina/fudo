// Real fetch implementation for menu items (PLAN.md Fase 3 documents this
// as `GET /api/v1/merchants/:id/menu_items`, but that route does not
// exist on the live backend — confirmed by curl: 404 RoutingError. The
// real, live route is `GET /api/v1/menu_items?merchant_id=X`, confirmed
// against the live /api-docs/v1/swagger.yaml and a working curl request.
// See ./README.md's "Live verification" section.
//
// `price` is a decimal column and — confirmed by curl, same as merchants —
// comes back as a JSON string, not a number. `section` is documented as
// nullable in the swagger spec, unlike lib/types' `MenuItem.section`
// (non-nullable) — defaulted to a fallback label since
// `groupMenuItemsBySection` (lib/mock/menu-items.ts) groups items by this
// field and a `null` key there would silently break that grouping.

import type { MenuItem } from "@/lib/types";
import { apiFetch } from "./client";

const UNSECTIONED_LABEL = "Otros";

interface RawMenuItem extends Omit<MenuItem, "price" | "section"> {
  price: string;
  section: string | null;
}

interface MenuItemsResponse {
  data: RawMenuItem[];
  meta: {
    current_page: number;
    total_pages: number;
    total_count: number;
    per_page: number;
  };
}

function parseMenuItem(raw: RawMenuItem): MenuItem {
  const price = Number(raw.price);
  return {
    ...raw,
    price: Number.isFinite(price) ? price : 0,
    section: raw.section ?? UNSECTIONED_LABEL,
  };
}

// Sanity bound, same reasoning as fetchMerchants — a merchant's menu is a
// small, bounded list, not something expected to need many pages.
const MAX_PAGES = 20;

export async function fetchMenuItemsForMerchant(
  merchantId: number,
): Promise<MenuItem[]> {
  const items: MenuItem[] = [];
  let page = 1;

  for (;;) {
    const response = await apiFetch<MenuItemsResponse>(
      `/menu_items?merchant_id=${merchantId}&page=${page}&per_page=100`,
    );
    items.push(...response.data.map(parseMenuItem));

    if (page >= response.meta.total_pages || page >= MAX_PAGES) {
      break;
    }
    page += 1;
  }

  return items;
}
