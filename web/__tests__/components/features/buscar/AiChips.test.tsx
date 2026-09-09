import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import { AiChips } from "@/components/features/buscar/AiChips";
import { DEFAULT_BUSCAR_PARAMS } from "@/lib/utils/buscar-href";

describe("AiChips", () => {
  it("renders nothing when there are no available tags", () => {
    const { container } = render(
      <AiChips current={DEFAULT_BUSCAR_PARAMS} activeTags={[]} availableTags={[]} />,
    );
    expect(container).toBeEmptyDOMElement();
  });

  it("renders a chip per available tag, falling back to the raw tag if unlabeled", () => {
    render(
      <AiChips
        current={DEFAULT_BUSCAR_PARAMS}
        activeTags={[]}
        availableTags={["vegano", "unknown_tag"]}
      />,
    );
    expect(screen.getByRole("link", { name: /Vegano/ })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /unknown_tag/ })).toBeInTheDocument();
  });

  it("adds a tag to the href when toggling an inactive tag on (OR-accumulating)", () => {
    render(
      <AiChips
        current={{ ...DEFAULT_BUSCAR_PARAMS, tags: "vegano" }}
        activeTags={["vegano"]}
        availableTags={["vegano", "wifi"]}
      />,
    );
    // "wifi" has no entry in TAG_LABELS (it's not part of the real 5-tag
    // vocabulary — see lib/mock/merchants.ts) — used here purely as an
    // arbitrary second tag to exercise multi-tag toggling, so it falls back
    // to rendering its own raw string (per the "falling back to the raw tag
    // if unlabeled" test above).
    const wifiChip = screen.getByRole("link", { name: /wifi/ });
    expect(wifiChip).toHaveAttribute("aria-pressed", "false");
    expect(wifiChip).toHaveAttribute("href", "/buscar?tags=vegano%2Cwifi");
  });

  it("removes a tag from the href when toggling an active tag off", () => {
    render(
      <AiChips
        current={{ ...DEFAULT_BUSCAR_PARAMS, tags: "vegano,wifi" }}
        activeTags={["vegano", "wifi"]}
        availableTags={["vegano", "wifi"]}
      />,
    );
    const veganoChip = screen.getByRole("link", { name: /Vegano/ });
    expect(veganoChip).toHaveAttribute("aria-pressed", "true");
    expect(veganoChip).toHaveAttribute("href", "/buscar?tags=wifi");
  });

  it("combines query, type, and tags together in one href", () => {
    render(
      <AiChips
        current={{ ...DEFAULT_BUSCAR_PARAMS, q: "centro", type: "bar", tags: "vegano" }}
        activeTags={["vegano"]}
        availableTags={["vegano", "wifi"]}
      />,
    );
    // "wifi" has no entry in TAG_LABELS (it's not part of the real 5-tag
    // vocabulary — see lib/mock/merchants.ts) — used here purely as an
    // arbitrary second tag to exercise multi-tag toggling, so it falls back
    // to rendering its own raw string (per the "falling back to the raw tag
    // if unlabeled" test above).
    const wifiChip = screen.getByRole("link", { name: /wifi/ });
    expect(wifiChip).toHaveAttribute(
      "href",
      "/buscar?q=centro&type=bar&tags=vegano%2Cwifi",
    );
  });
});
