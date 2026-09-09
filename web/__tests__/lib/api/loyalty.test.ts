import { describe, expect, it, vi, afterEach, beforeEach } from "vitest";

// Same convention as __tests__/lib/api/client.test.ts / merchants.test.ts —
// a mocked global `fetch`, no dependency on the live backend.

function jsonResponse(body: unknown) {
  return { ok: true, status: 200, json: () => Promise.resolve(body) } as Response;
}

describe("fetchLoyaltyRules", () => {
  beforeEach(() => {
    vi.stubGlobal("fetch", vi.fn());
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.resetModules();
  });

  it("fetches loyalty rules for a merchant with no Authorization header (public endpoint)", async () => {
    const { fetchLoyaltyRules } = await import("@/lib/api/loyalty");
    vi.mocked(fetch).mockResolvedValueOnce(
      jsonResponse({
        data: [
          {
            id: 1143,
            merchant_id: 257,
            visits_required: 2,
            reward_type: "discount_percent",
            reward_description: "10% de descuento en la cuenta total",
            is_permanent: false,
          },
        ],
        meta: { current_page: 1, total_pages: 1, total_count: 1, per_page: 100 },
      }),
    );

    const rules = await fetchLoyaltyRules(257);

    expect(rules).toEqual([
      {
        id: 1143,
        merchant_id: 257,
        visits_required: 2,
        reward_type: "discount_percent",
        reward_description: "10% de descuento en la cuenta total",
        is_permanent: false,
      },
    ]);
    const [url, init] = vi.mocked(fetch).mock.calls[0];
    expect(url).toContain("/loyalty_rules?merchant_id=257");
    expect((init as RequestInit | undefined)?.headers).toBeUndefined();
  });

  it("pages through every result when total_pages > 1", async () => {
    const { fetchLoyaltyRules } = await import("@/lib/api/loyalty");
    vi.mocked(fetch)
      .mockResolvedValueOnce(
        jsonResponse({
          data: [{ id: 1, merchant_id: 257, visits_required: 2, reward_type: "discount_percent", reward_description: "a", is_permanent: false }],
          meta: { current_page: 1, total_pages: 2, total_count: 2, per_page: 1 },
        }),
      )
      .mockResolvedValueOnce(
        jsonResponse({
          data: [{ id: 2, merchant_id: 257, visits_required: 10, reward_type: "discount_percent", reward_description: "b", is_permanent: true }],
          meta: { current_page: 2, total_pages: 2, total_count: 2, per_page: 1 },
        }),
      );

    const rules = await fetchLoyaltyRules(257);

    expect(rules.map((rule) => rule.id)).toEqual([1, 2]);
    expect(fetch).toHaveBeenCalledTimes(2);
  });
});
