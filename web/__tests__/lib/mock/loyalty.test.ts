import { describe, expect, it } from "vitest";
import { getLoyaltyRulesForMerchant, getMockVisitCount } from "@/lib/mock/loyalty";
import { MOCK_MERCHANTS } from "@/lib/mock/merchants";

// lib/mock/loyalty.ts is now only the local-dev-without-a-backend fallback
// (see its header comment) — `getLoyaltyProgress`/`buildSteps` moved to
// `buildLoyaltyProgress` in lib/data/loyalty.ts (see
// __tests__/lib/data/loyalty.test.ts) since that composition is generic
// over real or mock rules/visits, not mock-specific.

const merchant = MOCK_MERCHANTS[0];

describe("getLoyaltyRulesForMerchant", () => {
  it("always includes a permanent reward at the 10th visit", () => {
    const rules = getLoyaltyRulesForMerchant(merchant);
    const last = rules[rules.length - 1];
    expect(last.visits_required).toBe(10);
    expect(last.is_permanent).toBe(true);
  });

  it("adds an early reward only when the merchant has a rewardTeaser", () => {
    const withTeaser = getLoyaltyRulesForMerchant({ ...merchant, rewardTeaser: "Postre gratis" });
    expect(withTeaser.some((rule) => rule.visits_required === 2)).toBe(true);

    const withoutTeaser = getLoyaltyRulesForMerchant({ ...merchant, rewardTeaser: undefined });
    expect(withoutTeaser.some((rule) => rule.visits_required === 2)).toBe(false);
  });

  it("is deterministic across calls for the same merchant", () => {
    const a = getLoyaltyRulesForMerchant(merchant);
    const b = getLoyaltyRulesForMerchant(merchant);
    expect(a).toEqual(b);
  });
});

describe("getMockVisitCount", () => {
  it("is deterministic across calls (not randomized) for the same merchant", () => {
    expect(getMockVisitCount(merchant)).toBe(getMockVisitCount(merchant));
  });
});
