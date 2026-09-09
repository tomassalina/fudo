import { describe, expect, it, vi, beforeEach } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";

// Same mocking pattern as __tests__/lib/favorites/favorites-store.test.ts —
// use-visit-history.ts is now a module-level external store (see its header
// comment), so its `state`/`loadedForToken` persist across tests unless the
// module is freshly re-imported per test.
const {
  fetchVisitsMock,
  fetchVisitSummariesMock,
  getStoredTokenMock,
  forceLogoutMock,
  subscribeToSessionMock,
} = vi.hoisted(() => ({
  fetchVisitsMock: vi.fn(),
  fetchVisitSummariesMock: vi.fn(),
  getStoredTokenMock: vi.fn(),
  forceLogoutMock: vi.fn(),
  // Captures the listener `use-visit-history.ts` registers so tests can
  // simulate a real login/logout by invoking it directly, same as a real
  // `subscribeToSession()` call would on session change.
  subscribeToSessionMock: vi.fn(),
}));

vi.mock("@/lib/api/visits", () => ({
  fetchVisits: fetchVisitsMock,
  fetchVisitSummaries: fetchVisitSummariesMock,
}));

vi.mock("@/lib/auth/token-storage", () => ({
  getStoredToken: getStoredTokenMock,
}));

vi.mock("@/lib/session/session-provider", () => ({
  forceLogout: forceLogoutMock,
  subscribeToSession: subscribeToSessionMock,
}));

async function loadFreshHook() {
  vi.resetModules();
  return import("@/lib/visits/use-visit-history");
}

describe("useVisitHistory", () => {
  beforeEach(() => {
    fetchVisitsMock.mockReset().mockResolvedValue([]);
    fetchVisitSummariesMock.mockReset().mockResolvedValue([]);
    getStoredTokenMock.mockReset().mockReturnValue("test-jwt");
    forceLogoutMock.mockReset();
    subscribeToSessionMock.mockReset().mockImplementation(() => () => {});
  });

  it("loads visits and visit_summaries from the real API on mount", async () => {
    fetchVisitsMock.mockResolvedValue([
      { id: 822, consumer_id: "c1", merchant_id: 241, amount: "1500", reward_applied: true, visited_at: "2026-08-14T00:00:00.000Z" },
    ]);
    fetchVisitSummariesMock.mockResolvedValue([
      { id: 209, consumer_id: "c1", merchant_id: 249, count: 4, current_tier: "Nivel 4", last_visit_at: "2026-08-18T00:00:00.000Z" },
    ]);
    const { useVisitHistory } = await loadFreshHook();

    const { result } = renderHook(() => useVisitHistory());

    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(result.current.visits).toHaveLength(1);
    expect(result.current.visitSummaries).toHaveLength(1);
    expect(result.current.error).toBe(false);
  });

  it("never calls the API and returns empty results while logged out (no token)", async () => {
    getStoredTokenMock.mockReturnValue(null);
    const { useVisitHistory } = await loadFreshHook();

    const { result } = renderHook(() => useVisitHistory());

    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(fetchVisitsMock).not.toHaveBeenCalled();
    expect(fetchVisitSummariesMock).not.toHaveBeenCalled();
    expect(result.current.visits).toEqual([]);
    expect(result.current.visitSummaries).toEqual([]);
  });

  it("clears the session (forceLogout) on a 401 from either request", async () => {
    // `ApiError` must come from the SAME module instance use-visit-history.ts
    // resolves after `vi.resetModules()` (loadFreshHook, below) — an
    // `instanceof` check against an `ApiError` from a stale pre-reset module
    // instance would silently fail (same note as favorites-store.test.ts).
    const { useVisitHistory } = await loadFreshHook();
    const { ApiError } = await import("@/lib/api/client");
    fetchVisitsMock.mockRejectedValue(new ApiError("Not authenticated", { status: 401 }));

    const { result } = renderHook(() => useVisitHistory());

    await waitFor(() => expect(forceLogoutMock).toHaveBeenCalled());
    expect(result.current.visits).toEqual([]);
  });

  it("sets error without forceLogout on a non-401 failure", async () => {
    const { useVisitHistory } = await loadFreshHook();
    const { ApiError } = await import("@/lib/api/client");
    fetchVisitsMock.mockRejectedValue(new ApiError("boom", { status: 500 }));

    const { result } = renderHook(() => useVisitHistory());

    await waitFor(() => expect(result.current.error).toBe(true));
    expect(forceLogoutMock).not.toHaveBeenCalled();
  });

  it("resyncs when the session changes while the component stays mounted (Fix 3)", async () => {
    // Regression test: the previous implementation read `getStoredToken()`
    // once inside a `useEffect(..., [])` and never re-ran, so an
    // already-mounted consumer of this hook kept showing a stale, previous
    // consumer's visits after a forced logout/re-login — same bug class
    // favorites-store.ts's `subscribeToSession()` call fixes there.
    let sessionListener: (() => void) | undefined;
    subscribeToSessionMock.mockImplementation((listener: () => void) => {
      sessionListener = listener;
      return () => {};
    });
    fetchVisitsMock.mockResolvedValue([
      { id: 1, consumer_id: "c1", merchant_id: 1, amount: "100", reward_applied: false, visited_at: "2026-01-01T00:00:00.000Z" },
    ]);
    fetchVisitSummariesMock.mockResolvedValue([
      { id: 1, consumer_id: "c1", merchant_id: 1, count: 1, current_tier: "x", last_visit_at: "2026-01-01T00:00:00.000Z" },
    ]);
    const { useVisitHistory } = await loadFreshHook();

    const { result } = renderHook(() => useVisitHistory());
    await waitFor(() => expect(result.current.visits).toHaveLength(1));

    // Simulate a forced logout: the token disappears and session-provider
    // notifies every subscriber, exactly like a real `forceLogout()` call
    // would via `subscribeToSession`.
    getStoredTokenMock.mockReturnValue(null);
    expect(sessionListener).toBeDefined();
    sessionListener?.();

    await waitFor(() => expect(result.current.visits).toEqual([]));
    expect(result.current.visitSummaries).toEqual([]);

    // Simulate a fresh login for a different consumer: the store must
    // refetch instead of keeping the previous (now-stale) empty state.
    getStoredTokenMock.mockReturnValue("new-jwt");
    fetchVisitsMock.mockResolvedValue([
      { id: 2, consumer_id: "c2", merchant_id: 2, amount: "200", reward_applied: false, visited_at: "2026-02-01T00:00:00.000Z" },
    ]);
    fetchVisitSummariesMock.mockResolvedValue([
      { id: 2, consumer_id: "c2", merchant_id: 2, count: 2, current_tier: "x", last_visit_at: "2026-02-01T00:00:00.000Z" },
    ]);
    sessionListener?.();

    await waitFor(() => expect(result.current.visits).toEqual([expect.objectContaining({ consumer_id: "c2" })]));
  });

  it("settles loading to false after a 401 (regression: was stuck at true forever)", async () => {
    // This file's `subscribeToSession`/`forceLogout` mocks (see the top of
    // this file) are inert — the mocked `forceLogout` never re-enters
    // `ensureLoaded()`, so it can't reproduce the real race. The actual bug
    // only fires with the REAL `session-provider`, whose `forceLogout()`
    // synchronously calls `notify()`, which synchronously re-invokes this
    // module's `subscribeToSession()` listener *while the original
    // `ensureLoaded()` call for the 401 is still executing inside its own
    // `catch` block* — i.e. before that call's `loadInFlight` promise has
    // settled. That re-entrant call used to land in the
    // `if (loadInFlight) { await loadInFlight; return; }` dedup branch and
    // return without ever setting `loading: false`, while the resync
    // handler had just set `loading: true` right before calling it — so
    // `loading` got stuck at `true` forever. Reproducing this needs the
    // real, unmocked `session-provider` + `token-storage` (real
    // localStorage-backed token, real synchronous `notify()`), so this test
    // unmocks both instead of using the file's mocks.
    vi.doUnmock("@/lib/session/session-provider");
    vi.doUnmock("@/lib/auth/token-storage");
    vi.resetModules();

    try {
      const { ApiError } = await import("@/lib/api/client");
      fetchVisitsMock.mockReset().mockRejectedValue(new ApiError("Not authenticated", { status: 401 }));
      fetchVisitSummariesMock.mockReset().mockResolvedValue([]);

      const tokenStorage = await import("@/lib/auth/token-storage");
      tokenStorage.setStoredToken("test-jwt");

      const { useVisitHistory } = await import("@/lib/visits/use-visit-history");
      const { result } = renderHook(() => useVisitHistory());

      // The bug: this never resolved (timed out) before the fix — `loading`
      // stayed `true` forever even though the token really did get cleared.
      await waitFor(() => expect(result.current.loading).toBe(false));

      // Confirm this actually exercised the real forceLogout path (not a
      // false pass from some other code clearing the token).
      expect(tokenStorage.getStoredToken()).toBeNull();
    } finally {
      // Restore this file's mocks for every other test — doUnmock/resetModules
      // above would otherwise leak the real modules into later tests.
      vi.doMock("@/lib/session/session-provider", () => ({
        forceLogout: forceLogoutMock,
        subscribeToSession: subscribeToSessionMock,
      }));
      vi.doMock("@/lib/auth/token-storage", () => ({
        getStoredToken: getStoredTokenMock,
      }));
      vi.resetModules();
      window.localStorage.clear();
    }
  });
});
