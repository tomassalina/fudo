import { describe, expect, it } from "vitest";
import { priceBandForAmount, PRICE_BANDS } from "@/lib/utils/price-bands";

describe("priceBandForAmount", () => {
  it("returns null for a null estimate (no price mentioned)", () => {
    expect(priceBandForAmount(null)).toBeNull();
  });

  it("maps a value inside the first band to it", () => {
    expect(priceBandForAmount(10000)).toBe("0-20000");
  });

  it("maps a value on a band boundary to that band", () => {
    expect(priceBandForAmount(20000)).toBe("0-20000");
  });

  it("maps a value inside the middle band to it", () => {
    expect(priceBandForAmount(30000)).toBe("20000-40000");
  });

  it("maps a value above every band's ceiling to the last, open-ended band", () => {
    expect(priceBandForAmount(1_000_000)).toBe("40000-999999999");
  });

  it("maps a value of 0 to the first band, not null", () => {
    expect(priceBandForAmount(0)).toBe("0-20000");
  });

  it("PRICE_BANDS values match the /buscar price filter's own option values", () => {
    expect(PRICE_BANDS.map((b) => b.value)).toEqual([
      "0-20000",
      "20000-40000",
      "40000-999999999",
    ]);
  });
});
