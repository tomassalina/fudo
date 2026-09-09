"use client";

import { useEffect, useState } from "react";
import type { LoyaltyRule, Merchant } from "@/lib/types";
import { useSession } from "@/lib/session/use-session";
import { getLoyaltyRulesForMerchant, buildLoyaltyProgress } from "@/lib/data/loyalty";
import { useVisitHistory } from "./use-visit-history";

// Real per-merchant visit progress for the /buscar result cards' "X/Y
// visitas" badge — reuses the exact same data/derivation Perfil's
// LoyaltyCard (components/features/restaurantes/LoyaltyCard.tsx) already
// relies on for the merchant detail page: real `visit_summaries` count
// (useVisitHistory, a shared module-level cache — calling it from every
// mounted card costs nothing extra, see that hook's own doc comment) plus
// this merchant's real `loyalty_rules` ladder (getLoyaltyRulesForMerchant,
// lib/data/loyalty.ts's mock/real facade), combined through the same
// buildLoyaltyProgress used everywhere else loyalty progress is shown — so
// this card, the merchant detail page, and Perfil can never disagree about
// what "your progress at this merchant" means.
//
// `loyalty_rules` has no per-merchant embedding in the /buscar search
// response (confirmed against lib/data/search.ts and the backend's
// merchants controller) and no batch-by-merchant-ids endpoint either, so
// this fires one additional request per rendered card once authenticated —
// same one-request-per-merchant shape LoyaltyCard already does for a single
// merchant, just repeated per card here.

export interface MerchantVisitProgress {
  /** The consumer's real visit count at this merchant (visit_summaries). */
  visits: number;
  /** Visits required for the next reward not yet reached, or — once every
   * reward is reached — the ladder's own highest rung, so the badge still
   * reads as a real (if maxed-out) fraction instead of an undefined one. */
  target: number;
}

/**
 * Returns `null` (never a badge) while logged out, while still resolving,
 * or when this merchant has no loyalty rules at all — callers fall back to
 * the merchant's generic `rewardTeaser` copy in every one of those cases,
 * same as before this hook existed.
 */
export function useMerchantVisitProgress(merchant: Merchant): MerchantVisitProgress | null {
  const { isAuthenticated } = useSession();
  const { visitSummaries, loading: visitsLoading } = useVisitHistory();
  const [rules, setRules] = useState<LoyaltyRule[] | null>(null);

  // Same cancelled-flag/.then()-.catch() shape as LoyaltyCard's own effect
  // (see its header comment) — kept independent per card instead of a
  // shared batch fetch since `loyalty_rules` genuinely has no batch
  // endpoint to call instead (see file header above).
  //
  // No synchronous `setRules(null)` reset when logged out (would trip this
  // project's `react-hooks/set-state-in-effect` lint rule, same constraint
  // use-require-auth.ts's header comment documents) — unnecessary anyway,
  // since `loyalty_rules` is public, merchant-specific (not consumer-
  // specific) data: a stale `rules` value from a previous session is still
  // correct once re-authenticated, and the `!isAuthenticated` check below
  // already makes this hook return `null` regardless of `rules`.
  useEffect(() => {
    if (!isAuthenticated) return;
    let cancelled = false;

    getLoyaltyRulesForMerchant(merchant)
      .then((result) => {
        if (!cancelled) setRules(result);
      })
      .catch(() => {
        // A failed fetch for one card falls back to the generic teaser
        // rather than surfacing a per-card error — same "drop this one row"
        // reasoning lib/visits/build-visit-entries.ts documents for Perfil.
        if (!cancelled) setRules([]);
      });

    return () => {
      cancelled = true;
    };
  }, [merchant, isAuthenticated]);

  if (!isAuthenticated || visitsLoading || rules === null || rules.length === 0) {
    return null;
  }

  const visits = visitSummaries.find((summary) => summary.merchant_id === merchant.id)?.count ?? 0;
  const progress = buildLoyaltyProgress(rules, visits, true);
  const nextStep = progress.steps.find((step) => step.isNext);
  const target =
    nextStep?.rule?.visits_required ??
    progress.steps[progress.steps.length - 1]?.visitNumber ??
    progress.visits;

  return { visits: progress.visits, target };
}
