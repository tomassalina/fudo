import { describe, expect, it, vi, afterEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import type { Merchant } from "@/lib/types";

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

// Imported after the mocks so the component picks them up.
const { LoyaltyCard } = await import("@/components/features/restaurantes/LoyaltyCard");

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
  { id: 1, merchant_id: 1, visits_required: 2, reward_type: "free_item" as const, reward_description: "Postre gratis", is_permanent: false },
  { id: 2, merchant_id: 1, visits_required: 10, reward_type: "discount_percent" as const, reward_description: "5% siempre", is_permanent: true },
];

describe("LoyaltyCard", () => {
  afterEach(() => {
    useSessionMock.mockReset();
    useVisitHistoryMock.mockReset();
    getLoyaltyRulesForMerchantMock.mockReset();
  });

  it("renders the login CTA instead of a real visit ladder when logged out", async () => {
    useSessionMock.mockReturnValue({ isAuthenticated: false });
    useVisitHistoryMock.mockReturnValue({ visitSummaries: [], visits: [], loading: false, error: false });
    getLoyaltyRulesForMerchantMock.mockResolvedValue(rules);

    render(<LoyaltyCard merchant={merchant} />);

    await waitFor(() => expect(screen.getByText("Recompensas")).toBeInTheDocument());
    expect(screen.getByRole("link", { name: "Iniciar sesión" })).toHaveAttribute(
      "href",
      "/perfil",
    );
    expect(screen.queryByText(`Tu camino en ${merchant.name}`)).not.toBeInTheDocument();
  });

  it("renders the real visit ladder instead of the login CTA when authenticated, using the real visit_summaries count", async () => {
    useSessionMock.mockReturnValue({ isAuthenticated: true });
    useVisitHistoryMock.mockReturnValue({
      visitSummaries: [{ id: 1, consumer_id: "c1", merchant_id: 1, count: 3, current_tier: "x", last_visit_at: "2026-01-01" }],
      visits: [],
      loading: false,
      error: false,
    });
    getLoyaltyRulesForMerchantMock.mockResolvedValue(rules);

    render(<LoyaltyCard merchant={merchant} />);

    await waitFor(() => expect(screen.getByText(`Tu camino en ${merchant.name}`)).toBeInTheDocument());
    expect(screen.queryByText("Recompensas")).not.toBeInTheDocument();
    expect(screen.queryByRole("link", { name: "Iniciar sesión" })).not.toBeInTheDocument();
    expect(screen.getByText("VISITAS").previousElementSibling).toHaveTextContent("3");
  });

  it("stays in the loading state while authenticated and visit_summaries are still loading, even once loyalty_rules resolved (Fix 2)", async () => {
    // Regression test: the previous gate only waited on `rules` — for an
    // authenticated consumer, `rules` (public, fast) almost always resolves
    // before `useVisitHistory()`'s own `loading` flips to `false`, so this
    // rendered "0 visitas · Arrancá tu camino" for a real instant before
    // jumping to the true count. `visitSummaries` starting `[]` here (its
    // real initial value while loading) is exactly what used to produce
    // that flash of "0 visits".
    useSessionMock.mockReturnValue({ isAuthenticated: true });
    useVisitHistoryMock.mockReturnValue({ visitSummaries: [], visits: [], loading: true, error: false });
    getLoyaltyRulesForMerchantMock.mockResolvedValue(rules);

    const { container } = render(<LoyaltyCard merchant={merchant} />);

    await waitFor(() => expect(getLoyaltyRulesForMerchantMock).toHaveBeenCalled());
    expect(container.querySelector('[aria-busy="true"]')).toBeInTheDocument();
    expect(screen.queryByText(`Tu camino en ${merchant.name}`)).not.toBeInTheDocument();
    expect(screen.queryByText("VISITAS")).not.toBeInTheDocument();
  });

  it("shows an error state when the real loyalty_rules fetch fails", async () => {
    useSessionMock.mockReturnValue({ isAuthenticated: false });
    useVisitHistoryMock.mockReturnValue({ visitSummaries: [], visits: [], loading: false, error: false });
    getLoyaltyRulesForMerchantMock.mockRejectedValue(new Error("network down"));

    render(<LoyaltyCard merchant={merchant} />);

    await waitFor(() =>
      expect(screen.getByText(/No pudimos cargar los premios/)).toBeInTheDocument(),
    );
  });
});
