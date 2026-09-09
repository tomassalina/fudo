import { describe, expect, it, vi, afterEach, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import { AiSearchResolver } from "@/components/features/buscar/AiSearchResolver";

const { replaceMock } = vi.hoisted(() => ({ replaceMock: vi.fn() }));

vi.mock("next/navigation", () => ({
  useRouter: () => ({ replace: replaceMock }),
}));

const { resolveAiSearchFiltersMock } = vi.hoisted(() => ({
  resolveAiSearchFiltersMock: vi.fn(),
}));

vi.mock("@/lib/search/resolve-ai-search", () => ({
  resolveAiSearchFilters: resolveAiSearchFiltersMock,
}));

describe("AiSearchResolver", () => {
  beforeEach(() => {
    replaceMock.mockReset();
    resolveAiSearchFiltersMock.mockReset();
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it("renders the loading skeleton immediately", () => {
    resolveAiSearchFiltersMock.mockReturnValue(new Promise(() => {}));
    render(<AiSearchResolver query="algo picante y barato en Palermo" presetType="" />);

    expect(screen.getByText("Buscando lugares…")).toBeInTheDocument();
  });

  it("replaces the URL with the resolved filters as query params on success", async () => {
    resolveAiSearchFiltersMock.mockResolvedValue({
      type: "bar",
      neighborhood: "Palermo",
      tags: ["picante"],
      priceBand: "0-20000",
      q: null,
      mode: null,
    });

    render(<AiSearchResolver query="algo picante y barato en Palermo" presetType="" />);

    await waitFor(() => expect(replaceMock).toHaveBeenCalledTimes(1));
    const href = replaceMock.mock.calls[0][0] as string;
    expect(href).toContain("/buscar?");
    expect(href).toContain("type=bar");
    expect(href).toContain("hood=Palermo");
    expect(href).toContain("tags=picante");
    expect(href).toContain("price=0-20000");
    // No `q`/`ai`/`mode` param when Gemini found nothing beyond the
    // structured filters above (fully covered by type/hood/tags/price).
    expect(href).not.toContain("q=");
    expect(href).not.toContain("ai=");
    expect(href).not.toContain("mode=");
  });

  it("forwards `q`/`mode` on success when Gemini names a specific dish/merchant", async () => {
    resolveAiSearchFiltersMock.mockResolvedValue({
      type: null,
      neighborhood: null,
      tags: [],
      priceBand: null,
      q: "milanesa napolitana",
      mode: "platos",
    });

    render(<AiSearchResolver query="quiero comer milanesa napolitana" presetType="" />);

    await waitFor(() => expect(replaceMock).toHaveBeenCalledTimes(1));
    const href = replaceMock.mock.calls[0][0] as string;
    expect(href).toContain("q=milanesa");
    expect(href).toContain("mode=platos");
  });

  it("prefers an explicitly selected type over the one Gemini inferred", async () => {
    resolveAiSearchFiltersMock.mockResolvedValue({
      type: "cafe",
      neighborhood: null,
      tags: [],
      priceBand: null,
      q: null,
      mode: null,
    });

    render(<AiSearchResolver query="medialunas" presetType="bar" />);

    await waitFor(() => expect(replaceMock).toHaveBeenCalledTimes(1));
    const href = replaceMock.mock.calls[0][0] as string;
    expect(href).toContain("type=bar");
  });

  it("degrades to a plain name-only search on failure (e.g. Gemini/auth error)", async () => {
    resolveAiSearchFiltersMock.mockRejectedValue(new Error("boom"));

    render(<AiSearchResolver query="sushi" presetType="" />);

    await waitFor(() => expect(replaceMock).toHaveBeenCalledTimes(1));
    const href = replaceMock.mock.calls[0][0] as string;
    expect(href).toContain("q=sushi");
  });
});
