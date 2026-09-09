// Real fetch implementation for the public `loyalty_rules` resource
// (`backend/app/controllers/api/v1/loyalty_rules_controller.rb`). Unlike
// favorites/visits/consumer-settings, this endpoint has NO auth requirement
// at all — `before_action :authenticate_consumer!, except: %i[index show]`
// means `index` (the only action this file calls) is public. Every
// restaurant's loyalty rules are visible to any visitor, logged in or not;
// only the consumer's own *progress* against those rules needs a session
// (see lib/visits/use-visit-history.ts).
//
// Confirmed shape by curling the live backend (no token needed):
//   GET /api/v1/loyalty_rules?merchant_id=257
//   -> 200 {"data":[{"id":1143,"is_permanent":false,"merchant_id":257,
//            "reward_description":"10% de descuento en la cuenta total",
//            "reward_type":"discount_percent","visits_required":2}, ...],
//           "meta":{"current_page":1,"total_pages":1,"total_count":5,"per_page":20}}
// Rules are genuinely scoped per merchant (confirmed by comparing
// merchant_id=257 vs. 258 — the `merchant_id` filter is real, not decorative).

import type { LoyaltyRule, RewardType } from "@/lib/types";
import { apiFetch } from "./client";

export interface RawLoyaltyRule {
  id: number;
  merchant_id: number;
  visits_required: number;
  reward_type: RewardType;
  reward_description: string;
  is_permanent: boolean;
}

interface LoyaltyRulesListResponse {
  data: RawLoyaltyRule[];
  meta: {
    current_page: number;
    total_pages: number;
    total_count: number;
    per_page: number;
  };
}

/** `RawLoyaltyRule` and `LoyaltyRule` already match field-for-field — this
 * stays a separate (identity-shaped) conversion instead of just aliasing the
 * two types, per this repo's `Raw<Name>` convention: the wire shape is
 * confirmed independently of the domain type, so a real backend change that
 * only affects one of them doesn't quietly break the other. */
function toLoyaltyRule(raw: RawLoyaltyRule): LoyaltyRule {
  return {
    id: raw.id,
    merchant_id: raw.merchant_id,
    visits_required: raw.visits_required,
    reward_type: raw.reward_type,
    reward_description: raw.reward_description,
    is_permanent: raw.is_permanent,
  };
}

/** Every loyalty rule for one merchant, across all pages — a merchant's
 * reward ladder is a handful of rows (5 in every merchant checked live), so
 * pulling every page up front is simpler than paginating a UI element (the
 * loyalty ladder) that doesn't page. Same bound as `fetchFavorites` in
 * lib/api/favorites.ts. */
export async function fetchLoyaltyRules(merchantId: number): Promise<LoyaltyRule[]> {
  const rules: RawLoyaltyRule[] = [];
  let page = 1;
  const MAX_PAGES = 20;

  for (;;) {
    const response = await apiFetch<LoyaltyRulesListResponse>(
      `/loyalty_rules?merchant_id=${merchantId}&page=${page}&per_page=100`,
    );
    rules.push(...response.data);

    if (page >= response.meta.total_pages || page >= MAX_PAGES) break;
    page += 1;
  }

  return rules.map(toLoyaltyRule);
}
