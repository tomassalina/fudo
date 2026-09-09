import { describe, expect, it, vi, afterEach, beforeEach } from "vitest";
import { act } from "react";
import { renderToString } from "react-dom/server";
import { hydrateRoot, type Root } from "react-dom/client";

// This file drives `hydrateRoot` directly (not through
// `@testing-library/react`, which sets this for you) — required so React
// doesn't warn that effects triggered by `act()` are running outside of a
// recognized test environment.
declare global {
  var IS_REACT_ACT_ENVIRONMENT: boolean;
}
globalThis.IS_REACT_ACT_ENVIRONMENT = true;

// Real reproduction of the /perfil hard-reload bug (see
// lib/session/use-require-auth.ts's header comment for the full mechanics):
// this renders the REAL `SessionProvider` + `PerfilView` through an actual
// SSR (`renderToString`) → hydration (`hydrateRoot`) pass, exactly like a
// hard browser reload does, instead of `@testing-library/react`'s plain
// `render()` — which only ever does a fresh client mount and would never
// exercise `getServerSnapshot()` at all, so it could not have caught this
// bug. `next/navigation` is mocked (no real Next.js router needed for a
// bare React tree), everything else is the real implementation.
//
// `session-provider.tsx` keeps its session in module-level variables (by
// design — see that file's "External store" section), so each test below
// resets the module registry (`vi.resetModules()`) and re-imports both
// `SessionProvider` and `PerfilPage` fresh — otherwise the second test would
// see the first test's already-hydrated in-memory state instead of a real
// first load.
const { replaceMock, pushMock } = vi.hoisted(() => ({
  replaceMock: vi.fn(),
  pushMock: vi.fn(),
}));

vi.mock("next/navigation", () => ({
  useRouter: () => ({ replace: replaceMock, push: pushMock }),
}));

const SESSION_STORAGE_KEY = "fudo:consumer-session";
const TOKEN_STORAGE_KEY = "fudo:consumer-token";

const persistedConsumer = {
  id: "11112222-3333-4444-5555-666677778888",
  firstName: "Martina",
  lastName: "Giménez",
  email: "martina@example.com",
  phone: "+54 9 11 5555 5555",
};

async function loadFreshPerfilModules() {
  vi.resetModules();
  const { SessionProvider } = await import("@/lib/session/session-provider");
  const { default: PerfilPage } = await import("@/app/perfil/page");
  return { SessionProvider, PerfilPage };
}

describe("hard reload of /perfil with a valid persisted session", () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  afterEach(() => {
    replaceMock.mockReset();
    pushMock.mockReset();
    window.localStorage.clear();
    document.body.innerHTML = "";
  });

  it("does NOT redirect to /login once hydration settles with a valid session", async () => {
    // Simulates what a hard reload finds already in storage from a previous
    // real login/register (see session-provider.tsx's setSessionState).
    window.localStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(persistedConsumer));
    window.localStorage.setItem(TOKEN_STORAGE_KEY, "a-persisted-jwt");

    const { SessionProvider, PerfilPage } = await loadFreshPerfilModules();

    const html = renderToString(
      <SessionProvider>
        <PerfilPage />
      </SessionProvider>,
    );
    // Server-rendered HTML must be logged-out (getServerSnapshot()) — this
    // is the expected, unavoidable first paint, not the bug.
    expect(html).not.toContain("Martina Giménez");

    const container = document.createElement("div");
    container.innerHTML = html;
    document.body.appendChild(container);

    let root: Root;
    await act(async () => {
      root = hydrateRoot(
        container,
        <SessionProvider>
          <PerfilPage />
        </SessionProvider>,
      );
    });

    // The actual bug: without the useRequireAuth fix, this fires during
    // hydration's transient "logged out" render, before the store corrects
    // itself — sending a real, logged-in consumer to /login every time they
    // hard-reload /perfil.
    expect(replaceMock).not.toHaveBeenCalled();
    expect(pushMock).not.toHaveBeenCalled();

    // And the settled render shows the real profile, not a blank page.
    expect(container.textContent).toContain("Martina Giménez");

    act(() => root!.unmount());
  });

  it("DOES redirect to /login once hydration settles when there is no session", async () => {
    const { SessionProvider, PerfilPage } = await loadFreshPerfilModules();

    const html = renderToString(
      <SessionProvider>
        <PerfilPage />
      </SessionProvider>,
    );

    const container = document.createElement("div");
    container.innerHTML = html;
    document.body.appendChild(container);

    let root: Root;
    await act(async () => {
      root = hydrateRoot(
        container,
        <SessionProvider>
          <PerfilPage />
        </SessionProvider>,
      );
    });

    expect(replaceMock).toHaveBeenCalledWith("/login");

    act(() => root!.unmount());
  });
});
