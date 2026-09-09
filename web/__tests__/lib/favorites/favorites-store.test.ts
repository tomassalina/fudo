import { afterEach, describe, expect, it } from "vitest";
import { act, renderHook } from "@testing-library/react";
import {
  toggleFavoriteMerchant,
  useFavoriteMerchantIds,
  useIsMerchantFavorite,
} from "@/lib/favorites/favorites-store";

describe("favorites-store", () => {
  afterEach(() => {
    window.localStorage.clear();
    // Reset the module's in-memory cache back to what's on disk (empty) by
    // toggling off anything a previous test left favorited — cheaper than
    // vi.resetModules() and keeps the singleton store's contract honest
    // (it re-reads localStorage the first time, not on every test).
    const { result } = renderHook(() => useFavoriteMerchantIds());
    for (const id of result.current) {
      act(() => toggleFavoriteMerchant(id));
    }
  });

  it("starts with no favorited merchants", () => {
    const { result } = renderHook(() => useFavoriteMerchantIds());
    expect(result.current).toEqual([]);
  });

  it("toggles a merchant id on and off", () => {
    const { result: idsResult } = renderHook(() => useFavoriteMerchantIds());
    const { result: isFavResult } = renderHook(() => useIsMerchantFavorite(42));

    act(() => toggleFavoriteMerchant(42));
    expect(idsResult.current).toEqual([42]);
    expect(isFavResult.current).toBe(true);

    act(() => toggleFavoriteMerchant(42));
    expect(idsResult.current).toEqual([]);
    expect(isFavResult.current).toBe(false);
  });

  it("persists favorited ids to localStorage", () => {
    act(() => toggleFavoriteMerchant(7));
    const raw = window.localStorage.getItem("fudo:favorite-merchant-ids");
    expect(JSON.parse(raw ?? "[]")).toEqual([7]);
  });

  it("keeps multiple favorited merchants independently", () => {
    const { result } = renderHook(() => useFavoriteMerchantIds());

    act(() => toggleFavoriteMerchant(1));
    act(() => toggleFavoriteMerchant(2));
    expect(result.current).toEqual([1, 2]);

    act(() => toggleFavoriteMerchant(1));
    expect(result.current).toEqual([2]);
  });
});
