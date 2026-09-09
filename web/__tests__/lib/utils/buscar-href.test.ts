import { describe, expect, it } from "vitest";
import {
  buscarHref,
  countActiveFilters,
  DEFAULT_BUSCAR_PARAMS,
} from "@/lib/utils/buscar-href";

describe("buscarHref", () => {
  it("returns the bare path when nothing is active", () => {
    expect(buscarHref(DEFAULT_BUSCAR_PARAMS)).toBe("/buscar");
  });

  it("carries forward every active current param", () => {
    const current = { ...DEFAULT_BUSCAR_PARAMS, q: "sushi", type: "restaurant" };
    expect(buscarHref(current)).toBe("/buscar?q=sushi&type=restaurant");
  });

  it("applies an override on top of the current params", () => {
    const current = { ...DEFAULT_BUSCAR_PARAMS, q: "sushi" };
    expect(buscarHref(current, { type: "cafe" })).toBe(
      "/buscar?q=sushi&type=cafe",
    );
  });

  it("clears a field when the override is null", () => {
    const current = { ...DEFAULT_BUSCAR_PARAMS, q: "sushi", type: "cafe" };
    expect(buscarHref(current, { type: null })).toBe("/buscar?q=sushi");
  });

  it("clears a field when the override is an empty string", () => {
    const current = { ...DEFAULT_BUSCAR_PARAMS, tags: "vegano" };
    expect(buscarHref(current, { tags: "" })).toBe("/buscar");
  });

  it("keeps a fixed field order regardless of override order", () => {
    const current = { ...DEFAULT_BUSCAR_PARAMS, sort: "distancia", q: "pizza" };
    expect(buscarHref(current, { type: "pizzeria" })).toBe(
      "/buscar?q=pizza&type=pizzeria&sort=distancia",
    );
  });
});

describe("countActiveFilters", () => {
  it("is zero when nothing but q/mode/sort is set", () => {
    const current = { ...DEFAULT_BUSCAR_PARAMS, q: "sushi", mode: "platos", sort: "precio" };
    expect(countActiveFilters(current)).toBe(0);
  });

  it("counts type, each tag, price, hood, dist, and hideVisited as one each", () => {
    const current = {
      ...DEFAULT_BUSCAR_PARAMS,
      type: "cafe",
      tags: "vegano,sin_tacc",
      price: "0-20000",
      hood: "Palermo",
      dist: "3",
      hideVisited: "1",
    };
    expect(countActiveFilters(current)).toBe(7);
  });
});
