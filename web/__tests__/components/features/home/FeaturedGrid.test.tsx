import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import { FeaturedGrid } from "@/components/features/home/FeaturedGrid";
import type { Merchant } from "@/lib/types";

function makeMerchant(overrides: Partial<Merchant> & { id: number }): Merchant {
  return {
    name: `Merchant ${overrides.id}`,
    type: "restaurant",
    address: "",
    country: "Argentina",
    state: "",
    neighborhood: "Palermo",
    city: "Buenos Aires",
    latitude: -34.6,
    longitude: -58.4,
    tags: [],
    distanceKm: 1.2,
    ...overrides,
  };
}

describe("FeaturedGrid", () => {
  it("renders nothing when there are no merchants", () => {
    const { container } = render(<FeaturedGrid merchants={[]} />);
    expect(container).toBeEmptyDOMElement();
  });

  it("renders one card per merchant, linking to its detail page", () => {
    const merchants = [
      makeMerchant({ id: 1, name: "La Parrilla del Centro" }),
      makeMerchant({ id: 2, name: "Café Martínez", type: "cafe" }),
    ];

    render(<FeaturedGrid merchants={merchants} />);

    const first = screen.getByRole("link", { name: /La Parrilla del Centro/ });
    expect(first).toHaveAttribute("href", "/restaurantes/1");
    const second = screen.getByRole("link", { name: /Café Martínez/ });
    expect(second).toHaveAttribute("href", "/restaurantes/2");
  });

  it("shows the reward teaser and from-price when present", () => {
    const merchants = [
      makeMerchant({
        id: 3,
        name: "Bar Sur",
        rewardTeaser: "10% off",
        price_per_person_min: 8000,
      }),
    ];

    render(<FeaturedGrid merchants={merchants} />);

    expect(screen.getByText("10% off")).toBeInTheDocument();
    expect(screen.getByText(`desde $${(8000).toLocaleString("es-AR")}`)).toBeInTheDocument();
  });

  it("omits the reward teaser and price chip when absent", () => {
    const merchants = [makeMerchant({ id: 4, name: "Pizzería Güerrin" })];

    render(<FeaturedGrid merchants={merchants} />);

    expect(screen.queryByText(/off/)).not.toBeInTheDocument();
    expect(screen.queryByText(/^desde \$/)).not.toBeInTheDocument();
  });
});
