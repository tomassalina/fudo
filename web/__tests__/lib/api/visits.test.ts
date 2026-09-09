import { describe, expect, it, vi, afterEach, beforeEach } from "vitest";

function jsonResponse(body: unknown) {
  return { ok: true, status: 200, json: () => Promise.resolve(body) } as Response;
}

describe("fetchVisits / fetchVisitSummaries", () => {
  beforeEach(() => {
    vi.stubGlobal("fetch", vi.fn());
    localStorage.clear();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    localStorage.clear();
    vi.resetModules();
  });

  it("sends the stored bearer token and returns every visit on one page", async () => {
    localStorage.setItem("fudo:consumer-token", "test-jwt");
    const { fetchVisits } = await import("@/lib/api/visits");
    vi.mocked(fetch).mockResolvedValueOnce(
      jsonResponse({
        data: [
          {
            id: 822,
            consumer_id: "c1",
            merchant_id: 241,
            amount: "1500.0",
            reward_applied: true,
            visited_at: "2026-08-14T00:00:00.000Z",
          },
        ],
        meta: { current_page: 1, total_pages: 1, total_count: 1, per_page: 100 },
      }),
    );

    const visits = await fetchVisits();

    expect(visits).toHaveLength(1);
    expect(visits[0].merchant_id).toBe(241);
    const [url, init] = vi.mocked(fetch).mock.calls[0];
    expect(url).toContain("/visits?page=1&per_page=100");
    expect((init as RequestInit).headers).toEqual({ Authorization: "Bearer test-jwt" });
  });

  it("pages through every visit_summaries page", async () => {
    localStorage.setItem("fudo:consumer-token", "test-jwt");
    const { fetchVisitSummaries } = await import("@/lib/api/visits");
    vi.mocked(fetch)
      .mockResolvedValueOnce(
        jsonResponse({
          data: [{ id: 1, consumer_id: "c1", merchant_id: 240, count: 3, current_tier: "Nivel 3", last_visit_at: "2026-08-01T00:00:00.000Z" }],
          meta: { current_page: 1, total_pages: 2, total_count: 2, per_page: 1 },
        }),
      )
      .mockResolvedValueOnce(
        jsonResponse({
          data: [{ id: 2, consumer_id: "c1", merchant_id: 249, count: 4, current_tier: "Nivel 4", last_visit_at: "2026-08-18T00:00:00.000Z" }],
          meta: { current_page: 2, total_pages: 2, total_count: 2, per_page: 1 },
        }),
      );

    const summaries = await fetchVisitSummaries();

    expect(summaries.map((s) => s.merchant_id)).toEqual([240, 249]);
    expect(fetch).toHaveBeenCalledTimes(2);
  });
});
