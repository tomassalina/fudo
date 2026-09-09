import { describe, expect, it, vi, afterEach } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";
import type { Merchant } from "@/lib/types";

// Same mocking pattern as __tests__/components/features/restaurantes/LoyaltyCard.test.tsx
// — this hook reuses the exact same three dependencies.
const { useSessionMock, useVisitHistoryMock, getLoyaltyRulesForMerchantMock } = vi.hoisted(() => ({
  useSessionMock: vi.fn(),
  useVisitHistoryMock: vi.fn(),
  getLoyaltyRulesForMerchantMock: vi.fn(),
}));

vi.mock("@/lib/session/use-session", () => ({
  useSession: useSessionMock,
}));

vi.mock("@/lib/visits/use-visit-history", () => ({
  useVisitHistory: useVisitHistoryMock,
}));

vi.mock("@/lib/data/loyalty", async () => {
  const actual = await vi.importActual<typeof import("@/lib/data/loyalty")>("@/lib/data/loyalty");
  return { ...actual, getLoyaltyRulesForMerchant: getLoyaltyRulesForMerchantMock };
});

const { useMerchantVisitProgress } = await import("@/lib/visits/use-merchant-visit-progress");

const merchant: Merchant = {
  id: 1,
  name: "Sarkis",
  type: "restaurant",
  address: "",
  country: "Argentina",
  state: "",
  neighborhood: "Palermo",
  city: "Buenos Aires",
  latitude: -34.6,
  longitude: -58.4,
  tags: [],
  distanceKm: 0,
  rewardTeaser: "Postre gratis en tu segunda visita",
};

const rules = [
  { id: 1, merchant_id: 1, visits_required: 5, reward_type: "free_item" as const, reward_description: "Postre gratis", is_permanent: false },
  { id: 2, merchant_id: 1, visits_required: 10, reward_type: "discount_percent" as const, reward_description: "5% siempre", is_permanent: true },
];

describe("useMerchantVisitProgress", () => {
  afterEach(() => {
    useSessionMock.mockReset();
    useVisitHistoryMock.mockReset();
    getLoyaltyRulesForMerchantMock.mockReset();
  });

  it("returns null while logged out, without fetching loyalty_rules", async () => {
    useSessionMock.mockReturnValue({ isAuthenticated: false });
    useVisitHistoryMock.mockReturnValue({ visitSummaries: [], visits: [], loading: false, error: false });

    const { result } = renderHook(() => useMerchantVisitProgress(merchant));

    expect(result.current).toBeNull();
    expect(getLoyaltyRulesForMerchantMock).not.toHaveBeenCalled();
  });

  it("returns the real visits/target fraction once authenticated (e.g. 4/5 visitas)", async () => {
    useSessionMock.mockReturnValue({ isAuthenticated: true });
    useVisitHistoryMock.mockReturnValue({
      visitSummaries: [{ id: 1, consumer_id: "c1", merchant_id: 1, count: 4, current_tier: "x", last_visit_at: "2026-01-01" }],
      visits: [],
      loading: false,
      error: false,
    });
    getLoyaltyRulesForMerchantMock.mockResolvedValue(rules);

    const { result } = renderHook(() => useMerchantVisitProgress(merchant));

    await waitFor(() => expect(result.current).toEqual({ visits: 4, target: 5 }));
  });

  it("targets the ladder's highest rung once every reward is already reached", async () => {
    useSessionMock.mockReturnValue({ isAuthenticated: true });
    useVisitHistoryMock.mockReturnValue({
      visitSummaries: [{ id: 1, consumer_id: "c1", merchant_id: 1, count: 12, current_tier: "x", last_visit_at: "2026-01-01" }],
      visits: [],
      loading: false,
      error: false,
    });
    getLoyaltyRulesForMerchantMock.mockResolvedValue(rules);

    const { result } = renderHook(() => useMerchantVisitProgress(merchant));

    await waitFor(() => expect(result.current).toEqual({ visits: 12, target: 12 }));
  });

  it("returns null while visit_summaries are still loading, even once loyalty_rules resolved", async () => {
    useSessionMock.mockReturnValue({ isAuthenticated: true });
    useVisitHistoryMock.mockReturnValue({ visitSummaries: [], visits: [], loading: true, error: false });
    getLoyaltyRulesForMerchantMock.mockResolvedValue(rules);

    const { result } = renderHook(() => useMerchantVisitProgress(merchant));

    await waitFor(() => expect(getLoyaltyRulesForMerchantMock).toHaveBeenCalled());
    expect(result.current).toBeNull();
  });

  it("returns null when the merchant has no loyalty rules at all, so callers fall back to rewardTeaser", async () => {
    useSessionMock.mockReturnValue({ isAuthenticated: true });
    useVisitHistoryMock.mockReturnValue({ visitSummaries: [], visits: [], loading: false, error: false });
    getLoyaltyRulesForMerchantMock.mockResolvedValue([]);

    const { result } = renderHook(() => useMerchantVisitProgress(merchant));

    await waitFor(() => expect(getLoyaltyRulesForMerchantMock).toHaveBeenCalled());
    expect(result.current).toBeNull();
  });

  it("returns null instead of throwing when the loyalty_rules fetch fails", async () => {
    useSessionMock.mockReturnValue({ isAuthenticated: true });
    useVisitHistoryMock.mockReturnValue({ visitSummaries: [], visits: [], loading: false, error: false });
    getLoyaltyRulesForMerchantMock.mockRejectedValue(new Error("network down"));

    const { result } = renderHook(() => useMerchantVisitProgress(merchant));

    await waitFor(() => expect(getLoyaltyRulesForMerchantMock).toHaveBeenCalled());
    await waitFor(() => expect(result.current).toBeNull());
  });
});
