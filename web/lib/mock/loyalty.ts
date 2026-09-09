// Loyalty ladder derivation for the merchant detail page — see
// `docs/design-reference/Fudo App.dc.html`'s `loyaltyOf()` for the reference
// logic this mirrors (10-step ladder, an early reward, a permanent 5%
// discount at the top).
//
// There ARE live `loyalty_rules`/`visits`/`visit_summaries` endpoints now
// (see lib/api/loyalty.ts, lib/api/visits.ts, and lib/api/README.md's
// "Endpoint coverage" table) and a real per-consumer session (see
// lib/session/session-provider.tsx). This file is no longer the primary
// source of loyalty data — `lib/data/loyalty.ts` is, and its
// `buildLoyaltyProgress` is what actually composes rules + a real visit
// count into a `LoyaltyProgress` for `LoyaltyCard`/`PerfilView`. What's left
// here is ONLY the local-dev-without-a-backend fallback:
// `getLoyaltyRulesForMerchant` backs `lib/data/loyalty.ts`'s
// `!isApiConfigured()` branch, and `getMockVisitCount` backs both that same
// branch and `/buscar`'s unrelated `hideVisited` filter
// (app/buscar/page.tsx) — deterministic mock data, not hand-typed, exactly
// like `distanceKm`/`rewardTeaser` in lib/mock/merchants.ts.

import type { LoyaltyRule, Merchant } from "@/lib/types";

const LADDER_LENGTH = 10;
/** Visit count that unlocks the early reward — matches the design's "a la 2da ya tenés premio". */
const EARLY_REWARD_VISITS = 2;

/**
 * A merchant's loyalty ladder: an early reward (reusing the same
 * `rewardTeaser` copy already shown on its search card, so the two never
 * contradict each other) plus the permanent 5%-off reward every merchant
 * shares at visit 10, per the design's copy ("a la 10ma sos cliente fijo
 * con 5% siempre").
 */
export function getLoyaltyRulesForMerchant(merchant: Merchant): LoyaltyRule[] {
  const rules: LoyaltyRule[] = [];

  if (merchant.rewardTeaser) {
    rules.push({
      id: merchant.id * 100 + EARLY_REWARD_VISITS,
      merchant_id: merchant.id,
      visits_required: EARLY_REWARD_VISITS,
      reward_type: "free_item",
      reward_description: merchant.rewardTeaser,
      is_permanent: false,
    });
  }

  rules.push({
    id: merchant.id * 100 + LADDER_LENGTH,
    merchant_id: merchant.id,
    visits_required: LADDER_LENGTH,
    reward_type: "discount_percent",
    reward_description: "5% de descuento en todas tus compras, siempre.",
    is_permanent: true,
  });

  return rules;
}

/**
 * Placeholder visit count for local dev without a backend — deterministic
 * (not random) so the same merchant always renders the same value, seeded
 * off `merchant.id` the same way `distanceKm` is derived from real
 * coordinates rather than hand-typed. Real visit counts now come from
 * `visit_summaries` (lib/api/visits.ts) wherever a real consumer session is
 * available — this stays only as `/buscar`'s `hideVisited` filter fallback
 * (see app/buscar/page.tsx, a Server Component with no access to
 * `useSession()`/`useVisitHistory()`) and as `lib/data/loyalty.ts`'s own
 * `!isApiConfigured()` rules fallback needs no visit count of its own since
 * `useVisitHistory()` always calls the real backend directly (Pattern B, no
 * mock mode — see that hook's header comment).
 */
export function getMockVisitCount(merchant: Merchant): number {
  return (merchant.id * 3) % (LADDER_LENGTH - 1);
}
