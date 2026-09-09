import { describe, expect, it, vi, afterEach, beforeEach } from "vitest";

describe("resolveAiSearchFilters", () => {
  const originalEnv = process.env.NEXT_PUBLIC_API_BASE_URL;

  beforeEach(() => {
    vi.stubGlobal("fetch", vi.fn());
    localStorage.clear();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    localStorage.clear();
    if (originalEnv === undefined) {
      delete process.env.NEXT_PUBLIC_API_BASE_URL;
    } else {
      process.env.NEXT_PUBLIC_API_BASE_URL = originalEnv;
    }
    vi.resetModules();
  });

  it("throws without calling fetch when no backend is configured (mock/local mode)", async () => {
    delete process.env.NEXT_PUBLIC_API_BASE_URL;
    vi.resetModules();
    const { resolveAiSearchFilters } = await import("@/lib/search/resolve-ai-search");

    await expect(resolveAiSearchFilters("pizza")).rejects.toThrow();
    expect(fetch).not.toHaveBeenCalled();
  });

  it("maps the backend's structured filters onto this app's price-band vocabulary", async () => {
    process.env.NEXT_PUBLIC_API_BASE_URL = "http://localhost:3000/api/v1";
    vi.resetModules();
    localStorage.setItem("fudo:consumer-token", "test-jwt");
    const { resolveAiSearchFilters } = await import("@/lib/search/resolve-ai-search");

    vi.mocked(fetch).mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: () =>
        Promise.resolve({
          data: [],
          meta: { current_page: 1, total_pages: 1, total_count: 0, per_page: 20 },
          filters: {
            neighborhood: "Palermo",
            type: "bar",
            tags: ["picante"],
            price_per_person: 8000,
            open: null,
            reward: null,
            query: null,
            result_mode: null,
          },
        }),
    } as Response);

    const resolved = await resolveAiSearchFilters("algo picante y barato en Palermo");

    expect(resolved).toEqual({
      type: "bar",
      neighborhood: "Palermo",
      tags: ["picante"],
      priceBand: "0-20000",
      open: null,
      reward: null,
      q: null,
      mode: null,
    });
  });

  it("passes through a null price estimate as a null priceBand (no price filter)", async () => {
    process.env.NEXT_PUBLIC_API_BASE_URL = "http://localhost:3000/api/v1";
    vi.resetModules();
    const { resolveAiSearchFilters } = await import("@/lib/search/resolve-ai-search");

    vi.mocked(fetch).mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: () =>
        Promise.resolve({
          data: [],
          meta: { current_page: 1, total_pages: 1, total_count: 0, per_page: 20 },
          filters: {
            neighborhood: null,
            type: null,
            tags: [],
            price_per_person: null,
            open: null,
            reward: null,
            query: null,
            result_mode: null,
          },
        }),
    } as Response);

    const resolved = await resolveAiSearchFilters("un bar con buena onda");

    expect(resolved.priceBand).toBeNull();
  });

  it("maps open: true and reward: true onto the buscar `open`/`reward` param shapes", async () => {
    process.env.NEXT_PUBLIC_API_BASE_URL = "http://localhost:3000/api/v1";
    vi.resetModules();
    const { resolveAiSearchFilters } = await import("@/lib/search/resolve-ai-search");

    vi.mocked(fetch).mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: () =>
        Promise.resolve({
          data: [],
          meta: { current_page: 1, total_pages: 1, total_count: 0, per_page: 20 },
          filters: {
            neighborhood: null,
            type: null,
            tags: [],
            price_per_person: null,
            open: true,
            reward: true,
            query: null,
            result_mode: null,
          },
        }),
    } as Response);

    const resolved = await resolveAiSearchFilters("un bar abierto ahora con premios");

    expect(resolved.open).toBe("now");
    expect(resolved.reward).toBe("1");
  });

  it("maps open: false and reward: false to null (no filter), not a literal false param", async () => {
    process.env.NEXT_PUBLIC_API_BASE_URL = "http://localhost:3000/api/v1";
    vi.resetModules();
    const { resolveAiSearchFilters } = await import("@/lib/search/resolve-ai-search");

    vi.mocked(fetch).mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: () =>
        Promise.resolve({
          data: [],
          meta: { current_page: 1, total_pages: 1, total_count: 0, per_page: 20 },
          filters: {
            neighborhood: null,
            type: null,
            tags: [],
            price_per_person: null,
            open: false,
            reward: false,
            query: null,
            result_mode: null,
          },
        }),
    } as Response);

    const resolved = await resolveAiSearchFilters("un bar, no importa si está cerrado");

    expect(resolved.open).toBeNull();
    expect(resolved.reward).toBeNull();
  });

  it("maps `query`/`result_mode` onto the resolver's `q`/`mode` fields when Gemini names a specific dish", async () => {
    process.env.NEXT_PUBLIC_API_BASE_URL = "http://localhost:3000/api/v1";
    vi.resetModules();
    const { resolveAiSearchFilters } = await import("@/lib/search/resolve-ai-search");

    vi.mocked(fetch).mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: () =>
        Promise.resolve({
          data: [],
          meta: { current_page: 1, total_pages: 1, total_count: 0, per_page: 20 },
          filters: {
            neighborhood: null,
            type: null,
            tags: [],
            price_per_person: null,
            open: null,
            reward: null,
            query: "milanesa napolitana",
            result_mode: "platos",
          },
        }),
    } as Response);

    const resolved = await resolveAiSearchFilters("quiero comer milanesa napolitana");

    expect(resolved.q).toBe("milanesa napolitana");
    expect(resolved.mode).toBe("platos");
  });

  it("maps `result_mode: \"lugares\"` to a null `mode` (default/absence of the param)", async () => {
    process.env.NEXT_PUBLIC_API_BASE_URL = "http://localhost:3000/api/v1";
    vi.resetModules();
    const { resolveAiSearchFilters } = await import("@/lib/search/resolve-ai-search");

    vi.mocked(fetch).mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: () =>
        Promise.resolve({
          data: [],
          meta: { current_page: 1, total_pages: 1, total_count: 0, per_page: 20 },
          filters: {
            neighborhood: null,
            type: null,
            tags: [],
            price_per_person: null,
            open: null,
            reward: null,
            query: "la parrilla de Borges",
            result_mode: "lugares",
          },
        }),
    } as Response);

    const resolved = await resolveAiSearchFilters("busco la parrilla de Borges");

    expect(resolved.q).toBe("la parrilla de Borges");
    expect(resolved.mode).toBeNull();
  });
});
