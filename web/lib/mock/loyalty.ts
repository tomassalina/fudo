// Loyalty ladder derivation for the merchant detail page — see
// `docs/design-reference/Fudo App.dc.html`'s `loyaltyOf()` for the reference
// logic this mirrors (10-step ladder, an early reward, a permanent 5%
// discount at the top).
//
// There is no live `loyalty_rules`/`visits` endpoint yet (see
// lib/api/README.md's "Endpoint coverage" table) and no real per-consumer
// session (see its "Out of scope: auth" section — visit history lives in
// the mobile app). Both derivations below are therefore mock/UI-only,
// exactly like `distanceKm`/`rewardTeaser` in lib/mock/merchants.ts:
// deterministic, not hand-typed, and replaced wholesale once the real
// `loyalty_rules` + `visits` tables are wired through lib/data + a real
// `useSession()`. Every call site already reads through `isAuthenticated`
// correctly, so swapping this module's internals later is not a call-site
// change.

import type {
  LoyaltyProgress,
  LoyaltyRule,
  LoyaltyStep,
  Merchant,
} from "@/lib/types";

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
 * Placeholder visit count for the demo "logged in" state — deterministic
 * (not random) so the same merchant always renders the same progress
 * across a render, seeded off `merchant.id` the same way `distanceKm` is
 * derived from real coordinates rather than hand-typed. `useSession()` is a
 * real (mocked-login) session now, so this *is* reachable whenever a visitor
 * logs in — only the visit count is still fake, kept ready for when a real
 * `visits` table replaces it.
 */
export function getMockVisitCount(merchant: Merchant): number {
  return (merchant.id * 3) % (LADDER_LENGTH - 1);
}

function buildSteps(rules: LoyaltyRule[], visits: number): LoyaltyStep[] {
  const byVisits = new Map(rules.map((rule) => [rule.visits_required, rule]));
  const nextRule = rules.find((rule) => rule.visits_required > visits) ?? null;

  return Array.from({ length: LADDER_LENGTH }, (_, index) => {
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
 * note copy, branched on `isAuthenticated` exactly like the design's
 * `loyaltyOf()`: logged-out visitors see the program explained in the
 * abstract ("Así funcionan los premios"), logged-in consumers see their
 * real progress ("Arrancá tu camino" / "Faltan N visitas…" / "Sos cliente
 * fijo").
 */
export function getLoyaltyProgress(
  merchant: Merchant,
  isAuthenticated: boolean,
): LoyaltyProgress {
  const rules = getLoyaltyRulesForMerchant(merchant);
  const visits = isAuthenticated ? getMockVisitCount(merchant) : 0;
  const steps = buildSteps(rules, visits);
  const next = rules.find((rule) => rule.visits_required > visits) ?? null;
  const full = !next;

  const headline = !isAuthenticated
    ? "Así funcionan los premios"
    : full
      ? "Sos cliente fijo"
      : visits === 0
        ? "Arrancá tu camino"
        : next.visits_required - visits === 1
          ? "Falta 1 visita para tu próximo premio"
          : `Faltan ${next.visits_required - visits} visitas para tu próximo premio`;

  const sub = !isAuthenticated
    ? "Cada visita al local suma. A la 2ª ya tenés premio y a la 10ª sos cliente fijo con 5% siempre."
    : full
      ? "5% de descuento en todas tus compras, siempre."
      : next.visits_required - visits === 1
        ? `En tu próxima visita: ${next.reward_description}`
        : `A la visita ${next.visits_required}: ${next.reward_description}`;

  const note = !isAuthenticated
    ? "Iniciá sesión para empezar a sumar visitas con el QR del local."
    : full
      ? "Escaneá el QR en el local para aplicar tu 5% automáticamente."
      : "Cada visita se suma escaneando el QR del local o mostrando tu código.";

  return {
    authenticated: isAuthenticated,
    visits,
    steps,
    tierLabel: isAuthenticated ? "TU CAMINO" : "PROGRAMA DE FIDELIZACIÓN",
    headline,
    sub,
    note,
  };
}
