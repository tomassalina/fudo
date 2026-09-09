import { describe, expect, it, vi, afterEach, beforeEach } from "vitest";

// These tests exercise apiFetch entirely against a mocked global `fetch` —
// per PLAN.md's own instruction, unit tests must not depend on a live
// backend. No network call is ever made here, so this suite runs fine in CI
// even if http://localhost:3000 (the real dev backend) is unreachable.

describe("apiFetch", () => {
  beforeEach(() => {
    vi.stubGlobal("fetch", vi.fn());
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.resetModules();
  });

  it("returns the parsed JSON body on a successful response", async () => {
    const { apiFetch } = await import("@/lib/api/client");
    const body = { data: [{ id: 1, name: "Merchant 1" }] };
    vi.mocked(fetch).mockResolvedValueOnce(
      new Response(JSON.stringify(body), { status: 200 }),
    );

    const result = await apiFetch<typeof body>("/merchants");

    expect(result).toEqual(body);
    expect(fetch).toHaveBeenCalledTimes(1);
    expect(vi.mocked(fetch).mock.calls[0][0]).toBe("/merchants");
  });

  it("throws ApiError with the response status when the response is not ok", async () => {
    const { apiFetch, ApiError } = await import("@/lib/api/client");
    vi.mocked(fetch).mockResolvedValueOnce(
      new Response(null, { status: 404 }),
    );

    const failure = apiFetch("/merchants/999");
    await expect(failure).rejects.toBeInstanceOf(ApiError);
    await expect(failure).rejects.toMatchObject({
      name: "ApiError",
      status: 404,
    });
  });

  it("wraps a network failure (fetch rejecting) in an ApiError with no status", async () => {
    const { apiFetch, ApiError } = await import("@/lib/api/client");
    vi.mocked(fetch).mockRejectedValueOnce(new TypeError("Failed to fetch"));

    const failure = apiFetch("/merchants");
    await expect(failure).rejects.toBeInstanceOf(ApiError);
    await expect(failure).rejects.toMatchObject({
      status: undefined,
    });
  });
});

describe("isApiConfigured", () => {
  const originalEnv = process.env.NEXT_PUBLIC_API_BASE_URL;

  afterEach(() => {
    if (originalEnv === undefined) {
      delete process.env.NEXT_PUBLIC_API_BASE_URL;
    } else {
      process.env.NEXT_PUBLIC_API_BASE_URL = originalEnv;
    }
    vi.resetModules();
  });

  it("is false when NEXT_PUBLIC_API_BASE_URL is unset (mock mode, the default in this repo)", async () => {
    delete process.env.NEXT_PUBLIC_API_BASE_URL;
    vi.resetModules();
    const { isApiConfigured } = await import("@/lib/api/client");
    expect(isApiConfigured()).toBe(false);
  });

  it("is true when NEXT_PUBLIC_API_BASE_URL is set", async () => {
    process.env.NEXT_PUBLIC_API_BASE_URL = "https://api.example.com";
    vi.resetModules();
    const { isApiConfigured } = await import("@/lib/api/client");
    expect(isApiConfigured()).toBe(true);
  });
});
