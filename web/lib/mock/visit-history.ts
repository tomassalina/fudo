// Mocked "visit history per restaurant" for the Perfil page — see
// `docs/design-reference/Fudo App.dc.html`'s `visited`/`PLACES` (isProfile,
// pTab: "visitas") and `docs/design-reference/Fudo Customers.dc.html`'s wide
// equivalent for the reference this mirrors.
//
// There is no real `visits`/`visit_summaries` endpoint yet (see
// lib/api/README.md's "Endpoint coverage" table), so — same philosophy as
// lib/mock/loyalty.ts — this derives a plausible, *deterministic* history
// from the existing `MOCK_MERCHANTS` + `getLoyaltyProgress` instead of
// hand-typing a parallel fixture that could drift from it. A consumer's
// Perfil is expected to reuse the exact same loyalty ladder shown on that
// merchant's own detail page (LoyaltyCard), not a second, inconsistent mock.

import { MOCK_MERCHANTS } from "@/lib/mock/merchants";
import { getLoyaltyProgress } from "@/lib/mock/loyalty";
import type { LoyaltyProgress, LoyaltyRule, Merchant } from "@/lib/types";

/** Mirrors `tierOf()` in both design references: a coarse loyalty tier badge
 * derived purely from visit count, independent of any one merchant's own
 * reward ladder. */
export type VisitTier = "Bronce" | "Plata" | "Oro";

export function tierForVisits(visits: number): VisitTier {
  if (visits >= 8) return "Oro";
  if (visits >= 4) return "Plata";
  return "Bronce";
}

export interface VisitHistoryEntry {
  merchant: Merchant;
  progress: LoyaltyProgress;
  tier: VisitTier;
  /** "3 visitas · última hace 6 días" — mirrors `v.line` in the design
   * reference. The "hace N días" part is deterministic (seeded off the
   * merchant id), not wall-clock, since there's no real `visited_at` yet. */
  visitsLine: string;
}

function daysSinceLabel(merchantId: number): string {
  const days = (merchantId * 5) % 21 || 21;
  return days === 1 ? "hace 1 día" : `hace ${days} días`;
}

/**
 * Cap on how many merchants show up as "visited". `getMockVisitCount` gives
 * a nonzero count to 20 of the 30 `MOCK_MERCHANTS` (any id not divisible by
 * 3) — rendering all of them would read as "you've been to two-thirds of
 * every restaurant in the city", not a personal history. Real consumer data
 * would naturally be this size or smaller (most people have a handful of
 * regulars, not twenty), so this keeps the mock plausible instead of
 * exhaustive — same reasoning `hint-placeholder-count="4"` encodes in the
 * design reference's own `visited` list.
 */
const MAX_VISITED_MERCHANTS = 6;

/**
 * A consumer's visited restaurants, in the shape the Perfil page renders —
 * only merchants with at least one mocked visit (`getMockVisitCount > 0`)
 * count as "visited", same rule the design reference's `visited` filter
 * implies (a place with 0 visits doesn't show up in "Lugares que
 * visitaste") — capped and ranked by visit count, most-visited first, like
 * an actual "your regulars" list.
 */
export function getVisitHistory(): VisitHistoryEntry[] {
  return MOCK_MERCHANTS.map((merchant) => {
    const progress = getLoyaltyProgress(merchant, true);
    return { merchant, progress };
  })
    .filter(({ progress }) => progress.visits > 0)
    .sort((a, b) => b.progress.visits - a.progress.visits)
    .slice(0, MAX_VISITED_MERCHANTS)
    .map(({ merchant, progress }) => ({
      merchant,
      progress,
      tier: tierForVisits(progress.visits),
      visitsLine: `${progress.visits} ${progress.visits === 1 ? "visita" : "visitas"} · última ${daysSinceLabel(merchant.id)}`,
    }));
}

export type RewardStatus = "permanent" | "ready" | "upcoming";

export interface RewardEntry {
  merchant: Merchant;
  rule: LoyaltyRule;
  status: RewardStatus;
  /** Only set when `status === "upcoming"`. */
  visitsRemaining?: number;
}

/**
 * "Recompensas" section data — every reward the consumer has already earned
 * (`status: "permanent" | "ready"`, from `LoyaltyStep.done`) plus the single
 * next reward still pending per visited merchant (`status: "upcoming"`, from
 * `LoyaltyStep.isNext`). Reuses the exact same steps `LoyaltyCard` renders on
 * the merchant detail page instead of re-deriving "is this reward earned?"
 * with separate logic that could disagree with it.
 */
export function getAvailableRewards(): RewardEntry[] {
  const rewards: RewardEntry[] = [];

  for (const { merchant, progress } of getVisitHistory()) {
    for (const step of progress.steps) {
      if (step.done && step.rule) {
        rewards.push({
          merchant,
          rule: step.rule,
          status: step.rule.is_permanent ? "permanent" : "ready",
        });
      } else if (step.isNext && step.rule) {
        rewards.push({
          merchant,
          rule: step.rule,
          status: "upcoming",
          visitsRemaining: step.rule.visits_required - progress.visits,
        });
      }
    }
  }

  return rewards;
}
