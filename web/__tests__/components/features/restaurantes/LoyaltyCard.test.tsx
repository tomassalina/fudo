import { describe, expect, it, vi, afterEach } from "vitest";
import { render, screen } from "@testing-library/react";
import type { Merchant } from "@/lib/types";

const { useSessionMock } = vi.hoisted(() => ({
  useSessionMock: vi.fn(),
}));

vi.mock("@/lib/session/use-session", () => ({
  useSession: useSessionMock,
}));

// Imported after the mock so the component picks it up.
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

describe("LoyaltyCard", () => {
  afterEach(() => {
    useSessionMock.mockReset();
  });

  it("renders the login CTA instead of a real visit ladder when logged out", () => {
    useSessionMock.mockReturnValue({ isAuthenticated: false });

    render(<LoyaltyCard merchant={merchant} />);

    expect(screen.getByText("Recompensas")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Iniciar sesión" })).toHaveAttribute(
      "href",
      "/perfil",
    );
    expect(screen.queryByText(`Tu camino en ${merchant.name}`)).not.toBeInTheDocument();
  });

  it("renders the real visit ladder instead of the login CTA when authenticated", () => {
    useSessionMock.mockReturnValue({ isAuthenticated: true });

    render(<LoyaltyCard merchant={merchant} />);

    expect(screen.getByText(`Tu camino en ${merchant.name}`)).toBeInTheDocument();
    expect(screen.queryByText("Recompensas")).not.toBeInTheDocument();
    expect(screen.queryByRole("link", { name: "Iniciar sesión" })).not.toBeInTheDocument();
  });
});
