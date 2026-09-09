import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import { TypeFilterGrid } from "@/components/features/buscar/TypeFilterGrid";
import { DEFAULT_BUSCAR_PARAMS } from "@/lib/utils/buscar-href";

describe("TypeFilterGrid", () => {
  it("renders nothing when there are no available types", () => {
    const { container } = render(
      <TypeFilterGrid
        current={DEFAULT_BUSCAR_PARAMS}
        activeType={null}
        availableTypes={[]}
      />,
    );
    expect(container).toBeEmptyDOMElement();
  });

  it("renders one link per available type, with its label", () => {
    render(
      <TypeFilterGrid
        current={DEFAULT_BUSCAR_PARAMS}
        activeType={null}
        availableTypes={["restaurant", "cafe"]}
      />,
    );
    expect(screen.getByRole("link", { name: /Restaurante/ })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /Café/ })).toBeInTheDocument();
  });

  it("marks the active type as pressed and links to a URL without `type` (toggle off)", () => {
    render(
      <TypeFilterGrid
        current={DEFAULT_BUSCAR_PARAMS}
        activeType="cafe"
        availableTypes={["restaurant", "cafe"]}
      />,
    );
    const active = screen.getByRole("link", { name: /Café/ });
    expect(active).toHaveAttribute("aria-pressed", "true");
    expect(active).toHaveAttribute("href", "/buscar");

    const inactive = screen.getByRole("link", { name: /Restaurante/ });
    expect(inactive).toHaveAttribute("aria-pressed", "false");
    expect(inactive).toHaveAttribute("href", "/buscar?type=restaurant");
  });

  it("preserves the other current params when building a type link's href", () => {
    render(
      <TypeFilterGrid
        current={{ ...DEFAULT_BUSCAR_PARAMS, q: "pizza" }}
        activeType={null}
        availableTypes={["pizzeria"]}
      />,
    );
    const chip = screen.getByRole("link", { name: /Pizzería/ });
    expect(chip).toHaveAttribute("href", "/buscar?q=pizza&type=pizzeria");
  });
});
