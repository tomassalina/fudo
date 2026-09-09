// Data-layer facade for loyalty rules — see lib/data/merchants.ts for the
// mock/real switching rationale this mirrors (Pattern A: public resource,
// `isApiConfigured()` hard switch, no silent fallback once opted in).
//
// `loyalty_rules` is PUBLIC (no auth — see lib/api/loyalty.ts's header
// comment), so this facade only needs the merchant. A consumer's actual
// *progress* against these rules (visit count) is a separate, authenticated
// concern — see lib/visits/use-visit-history.ts — so `buildLoyaltyProgress`
// below takes `visits` as a plain number, sourced by the caller from wherever
// it has a real (or, when logged out, zero) visit count.

import type { LoyaltyProgress, LoyaltyRule, LoyaltyStep, Merchant } from "@/lib/types";
import {
  getLoyaltyRulesForMerchant as getMockLoyaltyRulesForMerchant,
} from "@/lib/mock/loyalty";
import { isApiConfigured } from "@/lib/api/client";
import { fetchLoyaltyRules } from "@/lib/api/loyalty";

/** A merchant's real loyalty ladder (mock fallback when there's no backend
 * configured — see lib/mock/loyalty.ts's header comment). */
export async function getLoyaltyRulesForMerchant(merchant: Merchant): Promise<LoyaltyRule[]> {
  if (!isApiConfigured()) {
    return getMockLoyaltyRulesForMerchant(merchant);
  }
  return fetchLoyaltyRules(merchant.id);
}

/** Defensive cap on how many rungs the ladder ever renders, regardless of
 * how high a merchant's highest `visits_required` is — protects the UI from
 * a pathological/misconfigured rule (e.g. `visits_required: 10000`) turning
 * into a ten-thousand-row list. No real merchant checked live came close to
 * this (highest seen: 10). */
const MAX_LADDER_STEPS = 30;

function buildLoyaltySteps(rules: LoyaltyRule[], visits: number): LoyaltyStep[] {
  if (rules.length === 0) return [];

  const highestRequired = rules.reduce(
    (max, rule) => Math.max(max, rule.visits_required),
    0,
  );
  // At least as long as the highest reward's threshold, but also at least
  // `visits` long so a consumer who's already past every listed reward still
  // sees their own step marked `done` instead of the ladder stopping short.
  const ladderLength = Math.min(Math.max(highestRequired, visits), MAX_LADDER_STEPS);

  const byVisits = new Map(rules.map((rule) => [rule.visits_required, rule]));
  const nextRule = rules.find((rule) => rule.visits_required > visits) ?? null;

  return Array.from({ length: ladderLength }, (_, index) => {
    const visitNumber = index + 1;
    const rule = byVisits.get(visitNumber) ?? null;
    return {
      visitNumber,
      rule,
      done: visits >= visitNumber,
      isHere: visits === visitNumber,
      isNext: nextRule?.visits_required === visitNumber,
    };
  });
}

/**
 * Full derived loyalty state for one merchant — steps plus the headline/sub/
 * note copy, branched on `isAuthenticated` the same way the previous
 * mock-only `getLoyaltyProgress` (lib/mock/loyalty.ts) was: logged-out
 * visitors see the program explained in the abstract, logged-in consumers
 * see their real progress. Generic over `rules`/`visits` (real or mock) —
 * the only mock-specific piece left is *deriving* those two inputs
 * (getLoyaltyRulesForMerchant above, and lib/visits/use-visit-history.ts for
 * `visits`), not this composition.
 */
export function buildLoyaltyProgress(
  rules: LoyaltyRule[],
  visits: number,
  isAuthenticated: boolean,
): LoyaltyProgress {
  const effectiveVisits = isAuthenticated ? visits : 0;
  const steps = buildLoyaltySteps(rules, effectiveVisits);
  const next = rules.find((rule) => rule.visits_required > effectiveVisits) ?? null;
  const full = rules.length > 0 && !next;
  // The reward shown once `full`: prefer an explicit permanent perk (a
  // merchant can have at most a few, but only one is typically the
  // "keep earning forever" one); fall back to the highest-threshold rule so
  // `full` never renders with no reward text at all.
  const topRule = rules.find((rule) => rule.is_permanent)
    ?? [...rules].sort((a, b) => b.visits_required - a.visits_required)[0]
    ?? null;

  const headline = !isAuthenticated
    ? "Así funcionan los premios"
    : full
      ? "Sos cliente fijo"
      : effectiveVisits === 0
        ? "Arrancá tu camino"
        : next && next.visits_required - effectiveVisits === 1
          ? "Falta 1 visita para tu próximo premio"
          : next
            ? `Faltan ${next.visits_required - effectiveVisits} visitas para tu próximo premio`
            : "Todavía no hay premios cargados";

  const sub = !isAuthenticated
    ? rules.length > 0
      ? "Cada visita suma para tus premios en este local."
      : "Este local todavía no cargó su programa de fidelización."
    : full
      ? (topRule?.reward_description ?? "Ya alcanzaste todos los premios de este local.")
      : next
        ? next.visits_required - effectiveVisits === 1
          ? `En tu próxima visita: ${next.reward_description}`
          : `A la visita ${next.visits_required}: ${next.reward_description}`
        : "Este local todavía no cargó su programa de fidelización.";

  const note = !isAuthenticated
    ? "Iniciá sesión para empezar a sumar visitas con el QR del local."
    : full
      ? "Escaneá el QR en el local para aplicar tu premio automáticamente."
      : "Cada visita se suma escaneando el QR del local o mostrando tu código.";

  return {
    authenticated: isAuthenticated,
    visits: effectiveVisits,
    steps,
    tierLabel: isAuthenticated ? "TU CAMINO" : "PROGRAMA DE FIDELIZACIÓN",
    headline,
    sub,
    note,
  };
}
