import { beforeEach, describe, expect, it, vi } from "vitest";
import { act, renderHook, waitFor } from "@testing-library/react";

// favorites-store.ts is now backed by the real `favorites` API (see its
// header comment) — these tests mock the API client and token storage
// instead of asserting on localStorage directly, and use `vi.resetModules()`
// per test (same reasoning as
// __tests__/lib/session/perfil-hydration-redirect.test.tsx) since the
// store's cache (`entries`/`loadedForToken`) lives in module-level state.
const {
  fetchFavoritesMock,
  createFavoriteMock,
  deleteFavoriteMock,
  getStoredTokenMock,
  forceLogoutMock,
  subscribeToSessionMock,
} = vi.hoisted(() => ({
  fetchFavoritesMock: vi.fn(),
  createFavoriteMock: vi.fn(),
  deleteFavoriteMock: vi.fn(),
  getStoredTokenMock: vi.fn(),
  forceLogoutMock: vi.fn(),
  // Real signature is `(listener) => unsubscribe`. These tests exercise
  // favorites-store in isolation (no real SessionProvider mounted), so the
  // store just needs a stable no-op subscription — it doesn't assert on
  // "resync on session change" here (that's covered by observing the
  // session-provider.tsx / favorites-store.ts integration directly).
  subscribeToSessionMock: vi.fn(() => () => {}),
}));

vi.mock("@/lib/api/favorites", () => ({
  fetchFavorites: fetchFavoritesMock,
  createFavorite: createFavoriteMock,
  deleteFavorite: deleteFavoriteMock,
}));

vi.mock("@/lib/auth/token-storage", () => ({
  getStoredToken: getStoredTokenMock,
}));

vi.mock("@/lib/session/session-provider", () => ({
  forceLogout: forceLogoutMock,
  subscribeToSession: subscribeToSessionMock,
}));

async function loadFreshStore() {
  vi.resetModules();
  return import("@/lib/favorites/favorites-store");
}

describe("favorites-store", () => {
  beforeEach(() => {
    fetchFavoritesMock.mockReset().mockResolvedValue([]);
    createFavoriteMock.mockReset();
    deleteFavoriteMock.mockReset();
    getStoredTokenMock.mockReset().mockReturnValue("test-jwt");
    forceLogoutMock.mockReset();
  });

  it("starts with no favorited merchants when the backend has none", async () => {
    const { useFavoriteMerchantIds } = await loadFreshStore();
    const { result } = renderHook(() => useFavoriteMerchantIds());

    await waitFor(() => expect(fetchFavoritesMock).toHaveBeenCalled());
    expect(result.current).toEqual([]);
  });

  it("loads favorited merchant ids from GET /api/v1/favorites on mount", async () => {
    fetchFavoritesMock.mockResolvedValue([
      { id: 1, consumer_id: "c1", merchant_id: 7, created_at: "2026-01-01T00:00:00.000Z" },
    ]);
    const { useFavoriteMerchantIds } = await loadFreshStore();
    const { result } = renderHook(() => useFavoriteMerchantIds());

    await waitFor(() => expect(result.current).toEqual([7]));
  });

  it("favorites a merchant via POST /api/v1/favorites", async () => {
    createFavoriteMock.mockResolvedValue({
      id: 99,
      consumer_id: "c1",
      merchant_id: 42,
      created_at: "2026-01-01T00:00:00.000Z",
    });
    const { useFavoriteMerchantIds, useIsMerchantFavorite, toggleFavoriteMerchant } =
      await loadFreshStore();
    const { result: idsResult } = renderHook(() => useFavoriteMerchantIds());
    const { result: isFavResult } = renderHook(() => useIsMerchantFavorite(42));
    await waitFor(() => expect(fetchFavoritesMock).toHaveBeenCalled());

    act(() => toggleFavoriteMerchant(42));

    await waitFor(() => expect(idsResult.current).toEqual([42]));
    expect(isFavResult.current).toBe(true);
    expect(createFavoriteMock).toHaveBeenCalledWith(42);
  });

  it("unfavorites via DELETE /api/v1/favorites/:id using the real favorite id", async () => {
    fetchFavoritesMock.mockResolvedValue([
      { id: 55, consumer_id: "c1", merchant_id: 7, created_at: "2026-01-01T00:00:00.000Z" },
    ]);
    deleteFavoriteMock.mockResolvedValue(undefined);
    const { useFavoriteMerchantIds, toggleFavoriteMerchant } = await loadFreshStore();
    const { result } = renderHook(() => useFavoriteMerchantIds());
    await waitFor(() => expect(result.current).toEqual([7]));

    act(() => toggleFavoriteMerchant(7));

    await waitFor(() => expect(result.current).toEqual([]));
    // The favorite's own id (55), never the merchant id (7) — this is
    // exactly the bug this store has to avoid: the API keys deletion off
    // Favorite#id, not merchant_id.
    expect(deleteFavoriteMock).toHaveBeenCalledWith(55);
  });

  it("is a no-op while logged out (no token)", async () => {
    getStoredTokenMock.mockReturnValue(null);
    const { useFavoriteMerchantIds, toggleFavoriteMerchant } = await loadFreshStore();
    const { result } = renderHook(() => useFavoriteMerchantIds());
    await waitFor(() => expect(result.current).toEqual([]));

    act(() => toggleFavoriteMerchant(42));

    expect(createFavoriteMock).not.toHaveBeenCalled();
    expect(result.current).toEqual([]);
  });

  it("clears the session (forceLogout) on a 401 from a protected favorite call", async () => {
    // `ApiError` must come from the SAME module instance favorites-store.ts
    // resolves after `vi.resetModules()` (loadFreshStore, below) — an
    // `instanceof` check against an `ApiError` from a stale pre-reset
    // module instance would silently fail.
    const { useFavoriteMerchantIds, toggleFavoriteMerchant } = await loadFreshStore();
    const { ApiError } = await import("@/lib/api/client");
    createFavoriteMock.mockRejectedValue(new ApiError("Not authenticated", { status: 401 }));
    const { result } = renderHook(() => useFavoriteMerchantIds());
    await waitFor(() => expect(fetchFavoritesMock).toHaveBeenCalled());

    act(() => toggleFavoriteMerchant(42));

    await waitFor(() => expect(forceLogoutMock).toHaveBeenCalled());
    expect(result.current).toEqual([]);
  });
});
