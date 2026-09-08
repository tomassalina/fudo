import { describe, expect, it, vi, beforeEach, afterEach } from "vitest";
import {
  parseDecimal,
  parseCoordinate,
  parseMerchant,
  type RawMerchant,
} from "@/lib/api/merchants";

describe("parseDecimal", () => {
  it("parses a valid decimal string", () => {
    expect(parseDecimal("12.5")).toBe(12.5);
  });

  it("parses a valid integer-looking string", () => {
    expect(parseDecimal("0")).toBe(0);
  });

  it("returns undefined for null", () => {
    expect(parseDecimal(null)).toBeUndefined();
  });

  it("returns undefined for undefined", () => {
    expect(parseDecimal(undefined)).toBeUndefined();
  });

  it("returns undefined for a malformed numeric string", () => {
    expect(parseDecimal("not-a-number")).toBeUndefined();
  });

  it("parses an empty string as 0 (JS's Number('') === 0, treated as a valid finite number)", () => {
    // Documents the actual (slightly surprising) behavior rather than the
    // ideal one: parseDecimal only guards against non-finite results, so an
    // empty string quietly becomes 0 instead of undefined.
    expect(parseDecimal("")).toBe(0);
  });
});

describe("parseCoordinate", () => {
  let warnSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
  });
  afterEach(() => warnSpy.mockRestore());

  it("parses a valid coordinate string", () => {
    expect(parseCoordinate("-34.603722", "latitude", 1)).toBeCloseTo(-34.603722);
  });

  it("parses the literal value 0 without treating it as invalid", () => {
    expect(parseCoordinate("0", "latitude", 1)).toBe(0);
  });

  it("returns NaN (the invalid-coordinate sentinel) for a malformed string", () => {
    const result = parseCoordinate("not-a-coordinate", "longitude", 42);
    expect(Number.isNaN(result)).toBe(true);
  });

  it("warns (does not throw) when the value is unparseable", () => {
    parseCoordinate("garbage", "latitude", 7);
    expect(warnSpy).toHaveBeenCalledTimes(1);
    expect(warnSpy.mock.calls[0][0]).toContain("7");
  });

  it("never silently defaults a truly malformed value to 0 (0,0 would be a fake real place)", () => {
    const result = parseCoordinate("N/A", "longitude", 3);
    expect(result).not.toBe(0);
    expect(Number.isNaN(result)).toBe(true);
  });
});

function makeRawMerchant(overrides: Partial<RawMerchant> = {}): RawMerchant {
  return {
    id: 1,
    name: "Merchant 1",
    type: "restaurant",
    city: "Buenos Aires",
    latitude: "-34.6",
    longitude: "-58.4",
    ...overrides,
  };
}

describe("parseMerchant", () => {
  it("parses the list-response shape: address/state/country/whatsapp/delivery_url/tags are all absent", () => {
    const raw = makeRawMerchant({
      neighborhood: "Palermo",
      price_per_person_min: "1000",
      price_per_person_max: "2000",
      cover_image_url: "https://example.com/cover.jpg",
      // Note: no address, state, country, whatsapp_number, delivery_url, tags —
      // exactly what GET /api/v1/merchants (list) returns.
    });

    const merchant = parseMerchant(raw);

    expect(merchant.id).toBe(1);
    expect(merchant.name).toBe("Merchant 1");
    expect(merchant.neighborhood).toBe("Palermo");
    expect(merchant.price_per_person_min).toBe(1000);
    expect(merchant.price_per_person_max).toBe(2000);
    // Fields the list endpoint never returns get sane, documented defaults.
    expect(merchant.address).toBe("");
    expect(merchant.state).toBe("");
    expect(merchant.country).toBe("Argentina");
    expect(merchant.whatsapp_number).toBeUndefined();
    expect(merchant.delivery_url).toBeUndefined();
    expect(merchant.tags).toEqual([]);
  });

  it("parses the detail-response shape: address/state/country/whatsapp/delivery_url/tags all come through", () => {
    const raw = makeRawMerchant({
      address: "Av. Corrientes 1234",
      state: "CABA",
      country: "Argentina",
      whatsapp_number: "+5491100000000",
      delivery_url: "https://delivery.example.com/1",
      tags: ["vegano", "delivery"],
    });

    const merchant = parseMerchant(raw);

    expect(merchant.address).toBe("Av. Corrientes 1234");
    expect(merchant.state).toBe("CABA");
    expect(merchant.country).toBe("Argentina");
    expect(merchant.whatsapp_number).toBe("+5491100000000");
    expect(merchant.delivery_url).toBe("https://delivery.example.com/1");
    expect(merchant.tags).toEqual(["vegano", "delivery"]);
  });

  it("parses valid latitude/longitude into finite numbers", () => {
    const merchant = parseMerchant(makeRawMerchant({ latitude: "-34.6", longitude: "-58.4" }));
    expect(merchant.latitude).toBeCloseTo(-34.6);
    expect(merchant.longitude).toBeCloseTo(-58.4);
  });

  it("uses the NaN sentinel for unparseable latitude/longitude instead of defaulting to 0", () => {
    const merchant = parseMerchant(makeRawMerchant({ latitude: "bad", longitude: "bad" }));
    expect(Number.isNaN(merchant.latitude)).toBe(true);
    expect(Number.isNaN(merchant.longitude)).toBe(true);
  });

  it("always defaults UI-only derived fields with no backend column", () => {
    const merchant = parseMerchant(makeRawMerchant());
    expect(merchant.topDish).toBeUndefined();
    expect(merchant.rewardTeaser).toBeUndefined();
    expect(merchant.distanceKm).toBe(0);
  });

  it("hides price fields (undefined) rather than defaulting to 0 when absent", () => {
    const merchant = parseMerchant(makeRawMerchant());
    expect(merchant.price_per_person_min).toBeUndefined();
    expect(merchant.price_per_person_max).toBeUndefined();
  });
});
