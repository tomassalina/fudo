import { describe, expect, it, vi, beforeEach } from "vitest";
import type { Merchant } from "@/lib/types";
import type { RawVisitSummary } from "@/lib/api/visits";

const { getMerchantByIdMock, getLoyaltyRulesForMerchantMock } = vi.hoisted(() => ({
  getMerchantByIdMock: vi.fn(),
  getLoyaltyRulesForMerchantMock: vi.fn(),
}));

vi.mock("@/lib/data/merchants", () => ({
  getMerchantById: getMerchantByIdMock,
}));

vi.mock("@/lib/data/loyalty", async () => {
  const actual = await vi.importActual<typeof import("@/lib/data/loyalty")>("@/lib/data/loyalty");
  return { ...actual, getLoyaltyRulesForMerchant: getLoyaltyRulesForMerchantMock };
});

const { buildVisitEntries, topTierFor } = await import("@/lib/visits/build-visit-entries");

function merchant(id: number): Merchant {
  return {
    id,
    name: `Merchant ${id}`,
    type: "restaurant",
    address: "",
    country: "Argentina",
    state: "",
    city: "Buenos Aires",
    latitude: 0,
    longitude: 0,
    tags: [],
    distanceKm: 0,
  };
}

describe("buildVisitEntries", () => {
  beforeEach(() => {
    getMerchantByIdMock.mockReset();
    getLoyaltyRulesForMerchantMock.mockReset();
  });

  it("resolves each visit_summaries row to a VisitHistoryEntry and derives rewards from the same progress", async () => {
    getMerchantByIdMock.mockImplementation((id: number) => Promise.resolve(merchant(id)));
    getLoyaltyRulesForMerchantMock.mockResolvedValue([
      { id: 1, merchant_id: 240, visits_required: 2, reward_type: "free_item", reward_description: "Postre gratis", is_permanent: false },
      { id: 2, merchant_id: 240, visits_required: 10, reward_type: "discount_percent", reward_description: "5% siempre", is_permanent: true },
    ]);
    const summaries: RawVisitSummary[] = [
      { id: 1, consumer_id: "c1", merchant_id: 240, count: 4, current_tier: "Nivel 4", last_visit_at: new Date().toISOString() },
    ];

    const { visitHistory, rewards } = await buildVisitEntries(summaries);

    expect(visitHistory).toHaveLength(1);
    expect(visitHistory[0].merchant.id).toBe(240);
    expect(visitHistory[0].progress.visits).toBe(4);
    expect(visitHistory[0].tier).toBe("Plata");

    // 4 visits: the visit-2 reward is earned ("ready"), the visit-10 reward is "upcoming".
    expect(rewards).toEqual([
      { merchant: expect.objectContaining({ id: 240 }), rule: expect.objectContaining({ visits_required: 2 }), status: "ready" },
      { merchant: expect.objectContaining({ id: 240 }), rule: expect.objectContaining({ visits_required: 10 }), status: "upcoming", visitsRemaining: 6 },
    ]);
  });

  it("caps to the top 6 merchants by visit count", async () => {
    getMerchantByIdMock.mockImplementation((id: number) => Promise.resolve(merchant(id)));
    getLoyaltyRulesForMerchantMock.mockResolvedValue([]);
    const summaries: RawVisitSummary[] = Array.from({ length: 10 }, (_, index) => ({
      id: index,
      consumer_id: "c1",
      merchant_id: 100 + index,
      count: index + 1,
      current_tier: "x",
      last_visit_at: new Date().toISOString(),
    }));

    const { visitHistory } = await buildVisitEntries(summaries);

    expect(visitHistory).toHaveLength(6);
    // Highest counts first (9..4), the six most-visited merchants.
    expect(visitHistory.map((entry) => entry.progress.visits)).toEqual([10, 9, 8, 7, 6, 5]);
  });

  it("drops a merchant that 404s (getMerchantById returns null) instead of throwing", async () => {
    getMerchantByIdMock.mockResolvedValue(null);
    getLoyaltyRulesForMerchantMock.mockResolvedValue([]);
    const summaries: RawVisitSummary[] = [
      { id: 1, consumer_id: "c1", merchant_id: 999, count: 1, current_tier: "x", last_visit_at: new Date().toISOString() },
    ];

    const { visitHistory, rewards } = await buildVisitEntries(summaries);

    expect(visitHistory).toEqual([]);
    expect(rewards).toEqual([]);
  });

  it("drops only the merchant whose resolution rejects (network/5xx failure) without collapsing the other rows (Fix 1)", async () => {
    // Regression test: the previous implementation resolved every merchant
    // inside a single `Promise.all` with no per-row try/catch, so a
    // rejection (not just a handled 404-returns-null) for ONE merchant
    // rejected the whole `Promise.all` — every other already-successful
    // merchant vanished too, and the rejection propagated unhandled up to
    // PerfilView.tsx's `.then()`.
    const consoleErrorSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    getMerchantByIdMock.mockImplementation((id: number) => {
      if (id === 500) return Promise.reject(new Error("network down"));
      return Promise.resolve(merchant(id));
    });
    getLoyaltyRulesForMerchantMock.mockResolvedValue([]);
    const summaries: RawVisitSummary[] = [
      { id: 1, consumer_id: "c1", merchant_id: 500, count: 5, current_tier: "x", last_visit_at: new Date().toISOString() },
      { id: 2, consumer_id: "c1", merchant_id: 240, count: 3, current_tier: "x", last_visit_at: new Date().toISOString() },
    ];

    const { visitHistory, rewards } = await buildVisitEntries(summaries);

    expect(visitHistory).toHaveLength(1);
    expect(visitHistory[0].merchant.id).toBe(240);
    expect(rewards).toEqual([]);
    expect(consoleErrorSpy).toHaveBeenCalled();
    consoleErrorSpy.mockRestore();
  });

  it("falls back to \"hace poco\" for a null last_visit_at instead of computing from the Unix epoch (Fix 4)", async () => {
    // Regression test: `visit_summary.last_visit_at` is a nullable
    // `timestamptz` in practice — `new Date(null).getTime()` is `0` (the
    // Unix epoch), NOT `NaN`, so a naive `Number.isNaN` guard alone would
    // render "~20000 days ago" instead of falling back.
    getMerchantByIdMock.mockImplementation((id: number) => Promise.resolve(merchant(id)));
    getLoyaltyRulesForMerchantMock.mockResolvedValue([]);
    const summaries: RawVisitSummary[] = [
      { id: 1, consumer_id: "c1", merchant_id: 240, count: 2, current_tier: "x", last_visit_at: null },
    ];

    const { visitHistory } = await buildVisitEntries(summaries);

    expect(visitHistory).toHaveLength(1);
    expect(visitHistory[0].visitsLine).toBe("2 visitas · última hace poco");
  });
});

describe("topTierFor", () => {
  it("returns Bronce for an empty visit history", () => {
    expect(topTierFor([])).toBe("Bronce");
  });
});
