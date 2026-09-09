// Real fetch implementations for the authenticated `favorites` resource
// (`backend/app/controllers/api/v1/favorites_controller.rb`). Every call
// here requires a bearer token — there is no mock/anonymous mode, unlike
// merchants/menu-items: favoriting only exists for a real, logged-in
// consumer now that auth is real (see lib/session/session-provider.tsx).
//
// Confirmed shapes by curling the live backend with a real token:
//   GET /api/v1/favorites
//   -> 200 {"data":[{"id":23,"consumer_id":"...","created_at":"...","merchant_id":240}, ...],"meta":{...}}
//   POST /api/v1/favorites {"favorite":{"merchant_id":240}}
//   -> 201 {"id":...,"consumer_id":"...","merchant_id":240,"created_at":"..."}
//   -> 422 {"errors":{"merchant_id":["has already been taken"]}} (already favorited)
//   DELETE /api/v1/favorites/:id -> 204 No Content

import { apiFetch } from "./client";
import { authHeader } from "@/lib/auth/token-storage";

export interface RawFavorite {
  id: number;
  consumer_id: string;
  merchant_id: number;
  created_at: string;
}

interface FavoritesListResponse {
  data: RawFavorite[];
  meta: {
    current_page: number;
    total_pages: number;
    total_count: number;
    per_page: number;
  };
}

/** Every favorite for the current consumer (identified by the bearer
 * token), across all pages — this MVP's per-consumer favorite count is tiny
 * (a handful of merchants), so pulling every page up front (same bound as
 * `fetchMerchants` in lib/api/merchants.ts) is simpler than wiring real
 * pagination into a tab that has none. */
export async function fetchFavorites(): Promise<RawFavorite[]> {
  const favorites: RawFavorite[] = [];
  let page = 1;
  const MAX_PAGES = 20;

  for (;;) {
    const response = await apiFetch<FavoritesListResponse>(
      `/favorites?page=${page}&per_page=100`,
      { headers: authHeader() },
    );
    favorites.push(...response.data);

    if (page >= response.meta.total_pages || page >= MAX_PAGES) break;
    page += 1;
  }

  return favorites;
}

export async function createFavorite(merchantId: number): Promise<RawFavorite> {
  return apiFetch<RawFavorite>("/favorites", {
    method: "POST",
    headers: { ...authHeader(), "Content-Type": "application/json" },
    body: JSON.stringify({ favorite: { merchant_id: merchantId } }),
  });
}

export async function deleteFavorite(favoriteId: number): Promise<void> {
  await apiFetch<void>(`/favorites/${favoriteId}`, {
    method: "DELETE",
    headers: authHeader(),
  });
}
