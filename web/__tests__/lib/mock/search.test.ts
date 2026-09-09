import { describe, expect, it } from "vitest";
import { searchMerchants } from "@/lib/mock/search";
import type { Merchant, MerchantType } from "@/lib/types";

function makeMerchant(overrides: Partial<Merchant> & { id: number }): Merchant {
  return {
    name: `Merchant ${overrides.id}`,
    type: "restaurant",
    address: "",
    country: "Argentina",
    state: "",
    neighborhood: "Palermo",
    city: "Buenos Aires",
    latitude: -34.6,
    longitude: -58.4,
    tags: [],
    topDish: undefined,
    distanceKm: 0,
    ...overrides,
  };
}

const merchants: Merchant[] = [
  makeMerchant({
    id: 1,
    name: "La Parrilla del Centro",
    type: "restaurant",
    neighborhood: "Palermo",
    tags: ["vegano", "delivery"],
    topDish: "Bife de chorizo",
  }),
  makeMerchant({
    id: 2,
    name: "Café Martínez",
    type: "cafe",
    neighborhood: "Recoleta",
    tags: ["wifi"],
    topDish: "Medialunas",
  }),
  makeMerchant({
    id: 3,
    name: "Bar Sur",
    type: "bar",
    neighborhood: "San Telmo",
    tags: ["vegano", "sin_tacc"],
    topDish: undefined,
  }),
  makeMerchant({
    id: 4,
    name: "Pizzería Güerrin",
    type: "pizzeria",
    neighborhood: "Palermo",
    tags: [],
    topDish: "Muzzarella",
  }),
];

describe("searchMerchants", () => {
  it("returns every merchant when no filters are given", () => {
    const result = searchMerchants(merchants, {});
    expect(result).toHaveLength(4);
  });

  describe("type filter", () => {
    it("keeps only merchants whose type matches exactly", () => {
      const result = searchMerchants(merchants, { type: "cafe" });
      expect(result.map((m) => m.id)).toEqual([2]);
    });

    it("returns an empty array when no merchant has that type", () => {
      const result = searchMerchants(merchants, {
        type: "food_truck" as MerchantType,
      });
      expect(result).toEqual([]);
    });
  });

  describe("tags filter", () => {
    it("OR's within tags: a merchant matches if it has at least one requested tag", () => {
      const result = searchMerchants(merchants, { tags: ["vegano"] });
      expect(result.map((m) => m.id).sort()).toEqual([1, 3]);
    });

    it("still OR's across multiple requested tags (union, not intersection)", () => {
      const result = searchMerchants(merchants, {
        tags: ["wifi", "sin_tacc"],
      });
      expect(result.map((m) => m.id).sort()).toEqual([2, 3]);
    });

    it("excludes merchants with no tags at all when a tag filter is set", () => {
      const result = searchMerchants(merchants, { tags: ["vegano"] });
      expect(result.some((m) => m.id === 4)).toBe(false);
    });

    it("returns everything when tags is an empty array (treated as unset)", () => {
      const result = searchMerchants(merchants, { tags: [] });
      expect(result).toHaveLength(4);
    });

    it("returns an empty array when no merchant has any requested tag", () => {
      const result = searchMerchants(merchants, { tags: ["nonexistent"] });
      expect(result).toEqual([]);
    });
  });

  describe("query text filter", () => {
    it("matches a case-insensitive substring of the merchant name", () => {
      const result = searchMerchants(merchants, { query: "parrilla" });
      expect(result.map((m) => m.id)).toEqual([1]);
    });

    it("does NOT match the neighborhood — name-only, per the /buscar search bar contract", () => {
      const result = searchMerchants(merchants, { query: "recoleta" });
      expect(result).toEqual([]);
    });

    it("does NOT match the top dish — name-only, per the /buscar search bar contract", () => {
      const result = searchMerchants(merchants, { query: "medialunas" });
      expect(result).toEqual([]);
    });

    it("does NOT match a raw tag value — name-only, per the /buscar search bar contract", () => {
      const result = searchMerchants(merchants, { query: "sin_tacc" });
      expect(result).toEqual([]);
    });

    it("trims whitespace and ignores case", () => {
      const result = searchMerchants(merchants, { query: "  GÜERRIN  " });
      expect(result.map((m) => m.id)).toEqual([4]);
    });

    it("returns everything for an empty/whitespace-only query", () => {
      const result = searchMerchants(merchants, { query: "   " });
      expect(result).toHaveLength(4);
    });

    it("returns an empty array when nothing matches", () => {
      const result = searchMerchants(merchants, { query: "sushi" });
      expect(result).toEqual([]);
    });
  });

  describe("combined filters", () => {
    it("ANDs type, tags, and query together", () => {
      // Only merchant 1 is a restaurant AND has the "vegano" tag AND matches "centro".
      const result = searchMerchants(merchants, {
        type: "restaurant",
        tags: ["vegano"],
        query: "centro",
      });
      expect(result.map((m) => m.id)).toEqual([1]);
    });

    it("returns empty when type and tags individually match different merchants", () => {
      // "cafe" matches merchant 2, "vegano" tag matches 1 and 3 — no overlap.
      const result = searchMerchants(merchants, {
        type: "cafe",
        tags: ["vegano"],
      });
      expect(result).toEqual([]);
    });

    it("does not silently drop every result when tags are combined with type (regression)", () => {
      // Regression guard for the earlier silent-empty-results bug: a type
      // that legitimately has tagged merchants must not come back empty.
      const result = searchMerchants(merchants, {
        type: "bar",
        tags: ["vegano", "sin_tacc"],
      });
      expect(result.map((m) => m.id)).toEqual([3]);
    });
  });
});
