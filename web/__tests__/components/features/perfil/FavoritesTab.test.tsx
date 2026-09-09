import { afterEach, describe, expect, it, vi } from "vitest";
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import type { Merchant } from "@/lib/types";

const { getMerchantByIdMock, fetchFavoritesMock, createFavoriteMock, deleteFavoriteMock } =
  vi.hoisted(() => ({
    getMerchantByIdMock: vi.fn(),
    fetchFavoritesMock: vi.fn(),
    createFavoriteMock: vi.fn(),
    deleteFavoriteMock: vi.fn(),
  }));

vi.mock("@/lib/data/merchants", () => ({
  getMerchantById: getMerchantByIdMock,
}));

// favorites-store.ts is now backed by the real `favorites` API — mock the
// API client and a logged-in token instead of localStorage (see
// __tests__/lib/favorites/favorites-store.test.ts for the same pattern).
// `vi.resetModules()` per test below because the store's own cache
// (`loadedForToken`) lives in module-level state and would otherwise skip
// the second test's `fetchFavorites` mock, thinking it already loaded.
vi.mock("@/lib/api/favorites", () => ({
  fetchFavorites: fetchFavoritesMock,
  createFavorite: createFavoriteMock,
  deleteFavorite: deleteFavoriteMock,
}));

vi.mock("@/lib/auth/token-storage", () => ({
  getStoredToken: () => "test-jwt",
  authHeader: () => ({ Authorization: "Bearer test-jwt" }),
}));

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

async function loadFreshFavoritesTab() {
  vi.resetModules();
  const { FavoritesTab } = await import("@/components/features/perfil/FavoritesTab");
  return FavoritesTab;
}

describe("FavoritesTab", () => {
  afterEach(() => {
    getMerchantByIdMock.mockReset();
    fetchFavoritesMock.mockReset();
    createFavoriteMock.mockReset();
    deleteFavoriteMock.mockReset();
  });

  it("shows the empty state when no merchant is favorited", async () => {
    fetchFavoritesMock.mockResolvedValue([]);
    const FavoritesTab = await loadFreshFavoritesTab();

    render(<FavoritesTab />);

    expect(
      screen.getByText("Marcá lugares con el corazón y aparecen acá."),
    ).toBeInTheDocument();
  });

  it("resolves and lists favorited merchants, and can unfavorite from the row", async () => {
    fetchFavoritesMock.mockResolvedValue([
      { id: 88, consumer_id: "c1", merchant_id: 257, created_at: "2026-01-01T00:00:00.000Z" },
    ]);
    deleteFavoriteMock.mockResolvedValue(undefined);
    getMerchantByIdMock.mockResolvedValue(mockMerchant);
    const FavoritesTab = await loadFreshFavoritesTab();

    render(<FavoritesTab />);

    await waitFor(() => {
      expect(screen.getByText("El Rincón de Gorriti")).toBeInTheDocument();
    });
    expect(screen.getByText("Bar · Palermo")).toBeInTheDocument();

    fireEvent.click(
      screen.getByRole("button", { name: "Quitar El Rincón de Gorriti de favoritos" }),
    );

    await waitFor(() => {
      expect(deleteFavoriteMock).toHaveBeenCalledWith(88);
    });
    await waitFor(() => {
      expect(
        screen.getByText("Marcá lugares con el corazón y aparecen acá."),
      ).toBeInTheDocument();
    });
  });
});
