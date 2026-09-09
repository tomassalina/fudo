import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import { FilterChips } from "@/components/buscar/FilterChips";

describe("FilterChips", () => {
  it("renders nothing when there are no available types or tags", () => {
    const { container } = render(
      <FilterChips
        query=""
        activeType={null}
        activeTags={[]}
        availableTypes={[]}
        availableTags={[]}
      />,
    );
    expect(container).toBeEmptyDOMElement();
  });

  it("renders a chip per available type, with its label", () => {
    render(
      <FilterChips
        query=""
        activeType={null}
        activeTags={[]}
        availableTypes={["restaurant", "cafe"]}
        availableTags={[]}
      />,
    );
    expect(screen.getByRole("link", { name: /Restaurante/ })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /Café/ })).toBeInTheDocument();
  });

  it("marks the active type chip as pressed and links to a URL without `type` (toggle off)", () => {
    render(
      <FilterChips
        query=""
        activeType="cafe"
        activeTags={[]}
        availableTypes={["restaurant", "cafe"]}
        availableTags={[]}
      />,
    );
    const active = screen.getByRole("link", { name: /Café/ });
    expect(active).toHaveAttribute("aria-pressed", "true");
    expect(active).toHaveAttribute("href", "/buscar");

    const inactive = screen.getByRole("link", { name: /Restaurante/ });
    expect(inactive).toHaveAttribute("aria-pressed", "false");
    expect(inactive).toHaveAttribute("href", "/buscar?type=restaurant");
  });

  it("preserves the query string when building a type chip's href", () => {
    render(
      <FilterChips
        query="pizza"
        activeType={null}
        activeTags={[]}
        availableTypes={["pizzeria"]}
        availableTags={[]}
      />,
    );
    const chip = screen.getByRole("link", { name: /Pizzería/ });
    expect(chip).toHaveAttribute("href", "/buscar?q=pizza&type=pizzeria");
  });

  it("renders a chip per available tag with its label, falling back to the raw tag if unlabeled", () => {
    render(
      <FilterChips
        query=""
        activeType={null}
        activeTags={[]}
        availableTypes={[]}
        availableTags={["vegano", "unknown_tag"]}
      />,
    );
    expect(screen.getByRole("link", { name: /Vegano/ })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /unknown_tag/ })).toBeInTheDocument();
  });

  it("adds a tag to the href when toggling an inactive tag on (OR-accumulating)", () => {
    render(
      <FilterChips
        query=""
        activeType={null}
        activeTags={["vegano"]}
        availableTypes={[]}
        availableTags={["vegano", "wifi"]}
      />,
    );
    const wifiChip = screen.getByRole("link", { name: /WiFi/ });
    expect(wifiChip).toHaveAttribute("aria-pressed", "false");
    expect(wifiChip).toHaveAttribute("href", "/buscar?tags=vegano%2Cwifi");
  });

  it("removes a tag from the href when toggling an active tag off", () => {
    render(
      <FilterChips
        query=""
        activeType={null}
        activeTags={["vegano", "wifi"]}
        availableTypes={[]}
        availableTags={["vegano", "wifi"]}
      />,
    );
    const veganoChip = screen.getByRole("link", { name: /Vegano/ });
    expect(veganoChip).toHaveAttribute("aria-pressed", "true");
    expect(veganoChip).toHaveAttribute("href", "/buscar?tags=wifi");
  });

  it("combines query, type, and tags together in one href", () => {
    render(
      <FilterChips
        query="centro"
        activeType="bar"
        activeTags={["vegano"]}
        availableTypes={["bar"]}
        availableTags={["vegano", "wifi"]}
      />,
    );
    const wifiChip = screen.getByRole("link", { name: /WiFi/ });
    expect(wifiChip).toHaveAttribute(
      "href",
      "/buscar?q=centro&type=bar&tags=vegano%2Cwifi",
    );
  });
});
