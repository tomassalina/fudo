import { describe, expect, it, vi, afterEach } from "vitest";
import { render, screen } from "@testing-library/react";

// Regression coverage for the Platos-tab text-search bug: `query` used to be
// forwarded into `searchMerchants` (merchant.name-only substring match, see
// lib/mock/search.ts) regardless of mode, so a dish-name query that didn't
// also happen to match a merchant name could never reach
// getDishSearchResults with the right candidates — see app/buscar/page.tsx's
// own comment on `merchantNameQuery`.
//
// BuscarPage is an async Server Component — it's called directly and
// awaited here (the documented pattern for testing RSCs with React Testing
// Library) rather than passed to `render()` as JSX. The heavy client-side
// shell (BuscarView, which pulls in session/location/viewport hooks and the
// map panel) and Header are mocked out to a plain prop dump so this test
// stays focused on BuscarPage's own data-fetching/filtering logic — the
// actual thing this fix touches — without needing to stand up session,
// geolocation, or map-library context just to render leaf UI this test
// doesn't care about.

vi.mock("@/components/layout/Header", () => ({
  Header: () => null,
}));

vi.mock("@/components/analytics/SearchAnalytics", () => ({
  SearchAnalytics: () => null,
}));

vi.mock("@/components/features/buscar/BuscarView", () => ({
  BuscarView: (props: {
    merchants: { name: string }[];
    dishes: { item: { name: string }; merchant: { name: string } }[];
  }) => (
    <div>
      <div data-testid="merchant-names">
        {props.merchants.map((m) => m.name).join(",")}
      </div>
      <div data-testid="dish-names">
        {props.dishes.map((d) => d.item.name).join(",")}
      </div>
    </div>
  ),
}));

// Imported after the mocks so the page picks them up.
const { default: BuscarPage } = await import("@/app/buscar/page");

function searchParams(params: Record<string, string>) {
  return { searchParams: Promise.resolve(params) } as Parameters<
    typeof BuscarPage
  >[0];
}

describe("BuscarPage", () => {
  afterEach(() => {
    vi.clearAllMocks();
  });

  it("Platos mode matches a dish name that does NOT match any merchant name", async () => {
    // "Tacos al pastor (3u)" belongs to merchant 1, "Don Chile Cantina" —
    // neither the merchant name nor its address contains "tacos", so this
    // only ever surfaces via dish-level matching (lib/data/menu-items.ts's
    // getDishSearchResults), never via the merchant.name-only prefilter.
    const jsx = await BuscarPage(searchParams({ mode: "platos", q: "tacos" }));
    render(jsx);

    expect(screen.getByTestId("dish-names").textContent).toContain(
      "Tacos al pastor (3u)",
    );
    // The full type/tag-filtered merchant candidate set must still include
    // Don Chile Cantina — Platos mode must NOT narrow merchants by name
    // before dish matching runs.
    expect(screen.getByTestId("merchant-names").textContent).toContain(
      "Don Chile Cantina",
    );
  });

  it("Lugares mode (default) still matches merchant name only, unchanged", async () => {
    const jsx = await BuscarPage(searchParams({ q: "tacos" }));
    render(jsx);

    // No merchant is literally named "tacos", so the name-only match (per
    // 0fdc167) must return nothing here.
    expect(screen.getByTestId("merchant-names").textContent).toBe("");
    expect(screen.getByTestId("dish-names").textContent).toBe("");
  });

  it("Lugares mode still matches an actual merchant name", async () => {
    const jsx = await BuscarPage(searchParams({ q: "Don Chile Cantina" }));
    render(jsx);

    expect(screen.getByTestId("merchant-names").textContent).toBe(
      "Don Chile Cantina",
    );
  });
});
