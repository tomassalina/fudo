// Real fetch implementations for the authenticated `visits`/`visit_summaries`
// resources (`backend/app/controllers/api/v1/visits_controller.rb` and
// `.../visit_summaries_controller.rb`). Both are `before_action
// :authenticate_consumer!` with no exceptions — unlike loyalty_rules
// (lib/api/loyalty.ts), there is no anonymous/public mode here at all, same
// as favorites.ts/consumer-settings.ts. Both are scoped server-side to
// `current_consumer.visits` / `current_consumer.visit_summaries` — no
// consumer_id needs to be sent, the token identifies the consumer.
//
// Confirmed shapes by curling the live backend with a real token:
//   GET /api/v1/visits
//   -> 200 {"data":[{"id":822,"amount":"...","consumer_id":"...",
//            "merchant_id":241,"reward_applied":true,
//            "visited_at":"2026-08-14T00:00:00.000Z"}, ...],
//           "meta":{"current_page":1,"total_pages":6,"total_count":116,"per_page":20}}
//   GET /api/v1/visit_summaries
//   -> 200 {"data":[{"id":209,"consumer_id":"...","count":4,
//            "current_tier":"Nivel 4 visitas",
//            "last_visit_at":"2026-08-18T00:00:00.000Z","merchant_id":249}, ...],
//           "meta":{...}}
// `amount` arrives as a decimal STRING on the wire, same as `RawGift.amount`
// in lib/api/gifts.ts — kept as a string here too (nothing in this app
// currently needs it as a number; see lib/types' `Visit` doc comment).

import { apiFetch } from "./client";
import { authHeader } from "@/lib/auth/token-storage";

export interface RawVisit {
  id: number;
  consumer_id: string;
  merchant_id: number;
  amount: string;
  reward_applied: boolean;
  visited_at: string;
}

export interface RawVisitSummary {
  id: number;
  consumer_id: string;
  merchant_id: number;
  count: number;
  current_tier: string;
  /** `timestamptz` in the schema (backend/db/structure.sql), WITHOUT
   * `NOT NULL` — and `visit_summary_params` on the Rails controller accepts
   * it as client-settable on create/update, so a real row can genuinely
   * have `last_visit_at: null`. See `daysSinceLabel()` in
   * lib/visits/build-visit-entries.ts for the null-safe rendering. */
  last_visit_at: string | null;
}

interface PaginatedResponse<T> {
  data: T[];
  meta: {
    current_page: number;
    total_pages: number;
    total_count: number;
    per_page: number;
  };
}

/** Shared pagination loop — same shape/bound as `fetchFavorites` in
 * lib/api/favorites.ts (MAX_PAGES 20, per_page 100). A consumer's full visit
 * history (116 rows for the demo consumer used to verify this live) fits
 * comfortably under that bound. */
async function fetchAllPages<T>(path: string): Promise<T[]> {
  const items: T[] = [];
  let page = 1;
  const MAX_PAGES = 20;

  for (;;) {
    const response = await apiFetch<PaginatedResponse<T>>(
      `${path}?page=${page}&per_page=100`,
      { headers: authHeader() },
    );
    items.push(...response.data);

    if (page >= response.meta.total_pages || page >= MAX_PAGES) break;
    page += 1;
  }

  return items;
}

/** Every visit for the current consumer (identified by the bearer token),
 * across all pages. */
export async function fetchVisits(): Promise<RawVisit[]> {
  return fetchAllPages<RawVisit>("/visits");
}

/** Every visit-summary row (one per merchant this consumer has ever visited)
 * for the current consumer, across all pages. */
export async function fetchVisitSummaries(): Promise<RawVisitSummary[]> {
  return fetchAllPages<RawVisitSummary>("/visit_summaries");
}
