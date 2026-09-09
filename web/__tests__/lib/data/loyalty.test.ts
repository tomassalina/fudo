import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { LoyaltyRule, Merchant } from "@/lib/types";

const merchant: Merchant = {
  id: 257,
  name: "Sarkis",
  type: "restaurant",
  address: "",
  country: "Argentina",
  state: "",
  city: "Buenos Aires",
  latitude: -34.6,
  longitude: -58.4,
  tags: [],
  distanceKm: 0,
};

const realRule: LoyaltyRule = {
  id: 1143,
  merchant_id: 257,
  visits_required: 2,
  reward_type: "discount_percent",
  reward_description: "10% de descuento en la cuenta total",
  is_permanent: false,
};

describe("getLoyaltyRulesForMerchant (facade)", () => {
  const originalEnv = process.env.NEXT_PUBLIC_API_BASE_URL;

  beforeEach(() => {
    vi.resetModules();
  });

  afterEach(() => {
    if (originalEnv === undefined) {
      delete process.env.NEXT_PUBLIC_API_BASE_URL;
    } else {
      process.env.NEXT_PUBLIC_API_BASE_URL = originalEnv;
    }
    vi.doUnmock("@/lib/api/loyalty");
    vi.doUnmock("@/lib/mock/loyalty");
    vi.resetModules();
  });

  it("calls the real fetchLoyaltyRules when the API is configured", async () => {
    process.env.NEXT_PUBLIC_API_BASE_URL = "https://api.example.com";
    const fetchLoyaltyRulesMock = vi.fn().mockResolvedValue([realRule]);
    vi.doMock("@/lib/api/loyalty", () => ({ fetchLoyaltyRules: fetchLoyaltyRulesMock }));

    const { getLoyaltyRulesForMerchant } = await import("@/lib/data/loyalty");
    const rules = await getLoyaltyRulesForMerchant(merchant);

    expect(fetchLoyaltyRulesMock).toHaveBeenCalledWith(257);
    expect(rules).toEqual([realRule]);
  });

  it("falls back to the mock ladder when the API is not configured", async () => {
    delete process.env.NEXT_PUBLIC_API_BASE_URL;
    const mockRulesFn = vi.fn().mockReturnValue([realRule]);
    vi.doMock("@/lib/mock/loyalty", async () => {
      const actual = await vi.importActual<typeof import("@/lib/mock/loyalty")>("@/lib/mock/loyalty");
      return { ...actual, getLoyaltyRulesForMerchant: mockRulesFn };
    });

    const { getLoyaltyRulesForMerchant } = await import("@/lib/data/loyalty");
    const rules = await getLoyaltyRulesForMerchant(merchant);

    expect(mockRulesFn).toHaveBeenCalledWith(merchant);
    expect(rules).toEqual([realRule]);
  });
});

describe("buildLoyaltyProgress", () => {
  const rules: LoyaltyRule[] = [
    {
      id: 1,
      merchant_id: 257,
      visits_required: 2,
      reward_type: "free_item",
      reward_description: "Postre gratis",
      is_permanent: false,
    },
    {
      id: 2,
      merchant_id: 257,
      visits_required: 10,
      reward_type: "discount_percent",
      reward_description: "5% de descuento siempre",
      is_permanent: true,
    },
  ];

  it("forces visits to 0 and shows the logged-out copy when not authenticated", async () => {
    const { buildLoyaltyProgress } = await import("@/lib/data/loyalty");
    const progress = buildLoyaltyProgress(rules, 8, false);

    expect(progress.authenticated).toBe(false);
    expect(progress.visits).toBe(0);
    expect(progress.headline).toBe("Así funcionan los premios");
    expect(progress.steps.every((step) => !step.done)).toBe(true);
  });

  it("marks exactly the steps up to the visit count as done, once authenticated", async () => {
    const { buildLoyaltyProgress } = await import("@/lib/data/loyalty");
    const progress = buildLoyaltyProgress(rules, 3, true);

    expect(progress.visits).toBe(3);
    for (const step of progress.steps) {
      expect(step.done).toBe(step.visitNumber <= 3);
    }
    expect(progress.headline).toContain("Faltan");
  });

  it("reports the permanent reward once every rule is reached", async () => {
    const { buildLoyaltyProgress } = await import("@/lib/data/loyalty");
    const progress = buildLoyaltyProgress(rules, 10, true);

    expect(progress.headline).toBe("Sos cliente fijo");
    expect(progress.sub).toBe("5% de descuento siempre");
  });

  it("builds an empty ladder without throwing when a merchant has no rules yet", async () => {
    const { buildLoyaltyProgress } = await import("@/lib/data/loyalty");
    const progress = buildLoyaltyProgress([], 0, true);

    expect(progress.steps).toEqual([]);
  });
});
