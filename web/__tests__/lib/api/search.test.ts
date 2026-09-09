import { describe, expect, it, vi, afterEach, beforeEach } from "vitest";

function jsonResponse(body: unknown) {
  return { ok: true, status: 200, json: () => Promise.resolve(body) } as Response;
}

// Covers the ONLY caller of POST /api/v1/search in this app — see this
// file's own header comment for why the plain /buscar text search never
// reaches it at all (that's lib/mock/search.ts + lib/data/search.ts, no
// network call involved).
describe("parseSearchQuery", () => {
  beforeEach(() => {
    vi.stubGlobal("fetch", vi.fn());
    localStorage.clear();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    localStorage.clear();
    vi.resetModules();
  });

  it("POSTs the query with the stored bearer token and returns the derived filters", async () => {
    localStorage.setItem("fudo:consumer-token", "test-jwt");
    const { parseSearchQuery } = await import("@/lib/api/search");
    vi.mocked(fetch).mockResolvedValueOnce(
      jsonResponse({
        data: [],
        meta: { current_page: 1, total_pages: 1, total_count: 0, per_page: 20 },
        filters: {
          neighborhood: "Palermo",
          type: null,
          tags: ["picante"],
          price_per_person: 8000,
        },
      }),
    );

    const filters = await parseSearchQuery("algo picante y barato en Palermo");

    expect(filters).toEqual({
      neighborhood: "Palermo",
      type: null,
      tags: ["picante"],
      price_per_person: 8000,
    });

    const [url, init] = vi.mocked(fetch).mock.calls[0];
    expect(url).toContain("/search");
    const request = init as RequestInit;
    expect(request.method).toBe("POST");
    expect(request.headers).toMatchObject({ Authorization: "Bearer test-jwt" });
    expect(JSON.parse(request.body as string)).toEqual({
      query: "algo picante y barato en Palermo",
    });
  });

  it("propagates ApiError (e.g. 401 when there's no signed-in consumer)", async () => {
    const { parseSearchQuery } = await import("@/lib/api/search");
    const { ApiError } = await import("@/lib/api/client");
    vi.mocked(fetch).mockResolvedValueOnce(
      new Response(JSON.stringify({ error: "Not authenticated" }), { status: 401 }),
    );

    await expect(parseSearchQuery("pizza")).rejects.toBeInstanceOf(ApiError);
  });
});
