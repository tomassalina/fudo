import { describe, expect, it, vi, afterEach } from "vitest";
import { render, screen } from "@testing-library/react";
import type { Merchant } from "@/lib/types";

// The reward-badge behavior is the only thing under test here — distance,
// favorites, and the real progress fetch are all covered by their own
// dedicated tests (use-merchant-visit-progress.test.ts, FavoriteButton's own
// suite), so they're stubbed out instead of re-exercised through this
// component.
const { useMerchantDistanceKmMock, useMerchantVisitProgressMock } = vi.hoisted(() => ({
  useMerchantDistanceKmMock: vi.fn(),
  useMerchantVisitProgressMock: vi.fn(),
}));

vi.mock("@/lib/location/use-merchant-distance", () => ({
  useMerchantDistanceKm: useMerchantDistanceKmMock,
}));

vi.mock("@/lib/visits/use-merchant-visit-progress", () => ({
  useMerchantVisitProgress: useMerchantVisitProgressMock,
}));

vi.mock("@/components/features/buscar/FavoriteButton", () => ({
  FavoriteButton: () => null,
}));

const { MerchantCard } = await import("@/components/features/buscar/MerchantCard");

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
  distanceKm: 2,
  rewardTeaser: "Postre gratis en tu segunda visita",
};

describe("MerchantCard reward badge", () => {
  afterEach(() => {
    useMerchantDistanceKmMock.mockReset();
    useMerchantVisitProgressMock.mockReset();
  });

  it("shows the generic rewardTeaser copy when logged out (no real progress)", () => {
    useMerchantDistanceKmMock.mockReturnValue(null);
    useMerchantVisitProgressMock.mockReturnValue(null);

    render(<MerchantCard merchant={merchant} layout="card" />);

    expect(screen.getByText(merchant.rewardTeaser as string)).toBeInTheDocument();
  });

  it("shows the real 'X/Y visitas' progress badge instead of rewardTeaser once authenticated", () => {
    useMerchantDistanceKmMock.mockReturnValue(null);
    useMerchantVisitProgressMock.mockReturnValue({ visits: 4, target: 5 });

    render(<MerchantCard merchant={merchant} layout="card" />);

    expect(screen.getByText("4/5 visitas")).toBeInTheDocument();
    expect(screen.queryByText(merchant.rewardTeaser as string)).not.toBeInTheDocument();
  });

  it("renders the same real progress badge in the row layout", () => {
    useMerchantDistanceKmMock.mockReturnValue(null);
    useMerchantVisitProgressMock.mockReturnValue({ visits: 7, target: 8 });

    render(<MerchantCard merchant={merchant} layout="row" />);

    expect(screen.getByText("7/8 visitas")).toBeInTheDocument();
  });

  it("shows no badge at all when there's no real progress and no rewardTeaser", () => {
    useMerchantDistanceKmMock.mockReturnValue(null);
    useMerchantVisitProgressMock.mockReturnValue(null);

    render(<MerchantCard merchant={{ ...merchant, rewardTeaser: undefined }} layout="card" />);

    expect(screen.queryByText(/visitas/)).not.toBeInTheDocument();
  });
});
