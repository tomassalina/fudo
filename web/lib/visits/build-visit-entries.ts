// Composes Perfil's "Lugares que visitaste" (VisitHistoryEntry[]) and
// "Recompensas" (RewardEntry[]) from real data — one `RawVisitSummary` row per
// visited merchant (lib/api/visits.ts), each merchant resolved via
// lib/data/merchants.ts's `getMerchantById` (same facade FavoritesTab.tsx
// already uses), and each merchant's real loyalty ladder via
// lib/data/loyalty.ts. Both entry lists are built from the exact same
// `LoyaltyProgress.steps` per merchant so they can never disagree about
// what's earned — same reasoning the old mock `getAvailableRewards`
// (lib/mock/visit-history.ts, deleted) documented.

import { getMerchantById } from "@/lib/data/merchants";
import { getLoyaltyRulesForMerchant, buildLoyaltyProgress } from "@/lib/data/loyalty";
import { tierForVisits } from "./tier";
import type { RawVisitSummary } from "@/lib/api/visits";
import type { RewardEntry, VisitHistoryEntry } from "@/lib/types";

/** Cap on how many merchants show up as "visited" — same UX reasoning (and
 * same number) as the old mock's `MAX_VISITED_MERCHANTS`: a real consumer's
 * "your regulars" list reads better short and ranked than exhaustive, and it
 * bounds how many merchant/loyalty_rules requests this fires (top N by visit
 * count, not all of them — the demo consumer has 27 `visit_summaries` rows). */
const MAX_VISITED_MERCHANTS = 6;

function daysSinceLabel(lastVisitAt: string | null): string {
  // Check for null/undefined BEFORE constructing the `Date` — `last_visit_at`
  // is a nullable `timestamptz` column (see `RawVisitSummary`'s doc comment
  // in lib/api/visits.ts), and `new Date(null).getTime()` is `0` (the Unix
  // epoch), NOT `NaN`. Relying on `Number.isNaN` alone would silently render
  // "~20000 days ago" for a real null row instead of falling back here.
  if (lastVisitAt == null) return "hace poco";
  const lastVisitMs = new Date(lastVisitAt).getTime();
  if (Number.isNaN(lastVisitMs)) return "hace poco";
  const days = Math.max(0, Math.floor((Date.now() - lastVisitMs) / 86_400_000));
  if (days <= 0) return "hoy";
  return days === 1 ? "hace 1 día" : `hace ${days} días`;
}

export interface VisitEntries {
  visitHistory: VisitHistoryEntry[];
  rewards: RewardEntry[];
}

/** Ranks a consumer's real `visit_summaries` by visit count, resolves the
 * top `MAX_VISITED_MERCHANTS` to real merchants + real loyalty rules, and
 * derives both Perfil sections from the result. Merchants that fail to
 * resolve are dropped rather than surfacing a page-level error for one bad
 * row — both a confirmed-gone merchant (`getMerchantById` returns `null` on
 * a 404, handled below) and a genuine per-row failure (network error, 5xx
 * from either `getMerchantById` or `getLoyaltyRulesForMerchant`): each
 * resolution runs in its own try/catch specifically so ONE merchant's
 * network failure can't reject the whole `Promise.all` and collapse every
 * other already-succeeding row — a consumer with 6 real visited merchants
 * shouldn't see an empty "Visitas" tab because one of the six had a
 * transient 500. */
export async function buildVisitEntries(
  visitSummaries: RawVisitSummary[],
): Promise<VisitEntries> {
  const topSummaries = [...visitSummaries]
    .filter((summary) => summary.count > 0)
    .sort((a, b) => b.count - a.count)
    .slice(0, MAX_VISITED_MERCHANTS);

  const resolved = await Promise.all(
    topSummaries.map(async (summary) => {
      try {
        const merchant = await getMerchantById(summary.merchant_id);
        if (!merchant) return null;
        const rules = await getLoyaltyRulesForMerchant(merchant);
        const progress = buildLoyaltyProgress(rules, summary.count, true);
        return { merchant, summary, progress };
      } catch (error) {
        // Network/5xx failure resolving this one merchant or its loyalty
        // rules — drop just this row, same as the 404 case above, instead
        // of rejecting the whole `Promise.all` for every other merchant.
        console.error(
          `buildVisitEntries: failed to resolve merchant ${summary.merchant_id}`,
          error,
        );
        return null;
      }
    }),
  );

  const visitHistory: VisitHistoryEntry[] = [];
  const rewards: RewardEntry[] = [];

  for (const entry of resolved) {
    if (!entry) continue;
    const { merchant, summary, progress } = entry;

    visitHistory.push({
      merchant,
      progress,
      tier: tierForVisits(progress.visits),
      visitsLine: `${progress.visits} ${progress.visits === 1 ? "visita" : "visitas"} · última ${daysSinceLabel(summary.last_visit_at)}`,
    });

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

  return { visitHistory, rewards };
}

/** Highest tier across every visited merchant — feeds `ProfileHeader`'s
 * badge, same derivation `PerfilView` used against the old mock data. */
export function topTierFor(visitHistory: VisitHistoryEntry[]): ReturnType<typeof tierForVisits> {
  if (visitHistory.length === 0) return tierForVisits(0);
  return tierForVisits(Math.max(...visitHistory.map((entry) => entry.progress.visits)));
}
