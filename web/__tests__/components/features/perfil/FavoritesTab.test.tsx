import { afterEach, describe, expect, it, vi } from "vitest";
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import type { Merchant } from "@/lib/types";

const { getMerchantByIdMock } = vi.hoisted(() => ({
  getMerchantByIdMock: vi.fn(),
}));

vi.mock("@/lib/data/merchants", () => ({
  getMerchantById: getMerchantByIdMock,
}));

const { FavoritesTab } = await import("@/components/features/perfil/FavoritesTab");
const { toggleFavoriteMerchant } = await import("@/lib/favorites/favorites-store");

const mockMerchant: Merchant = {
  id: 257,
  name: "El Rincón de Gorriti",
  type: "bar",
  address: "Gorriti 4500",
  country: "Argentina",
  state: "Ciudad Autónoma de Buenos Aires",
  neighborhood: "Palermo",
  city: "Buenos Aires",
  latitude: -34.58,
  longitude: -58.43,
  tags: [],
  distanceKm: 0,
};

describe("FavoritesTab", () => {
  afterEach(() => {
    window.localStorage.clear();
    getMerchantByIdMock.mockReset();
  });

  it("shows the empty state when no merchant is favorited", () => {
    render(<FavoritesTab />);
    expect(
      screen.getByText("Marcá lugares con el corazón y aparecen acá."),
    ).toBeInTheDocument();
  });

  it("resolves and lists favorited merchants, and can unfavorite from the row", async () => {
    getMerchantByIdMock.mockResolvedValue(mockMerchant);
    toggleFavoriteMerchant(257);

    render(<FavoritesTab />);

    await waitFor(() => {
      expect(screen.getByText("El Rincón de Gorriti")).toBeInTheDocument();
    });
    expect(screen.getByText("Bar · Palermo")).toBeInTheDocument();

    fireEvent.click(
      screen.getByRole("button", { name: "Quitar El Rincón de Gorriti de favoritos" }),
    );

    await waitFor(() => {
      expect(
        screen.getByText("Marcá lugares con el corazón y aparecen acá."),
      ).toBeInTheDocument();
    });
  });
});
