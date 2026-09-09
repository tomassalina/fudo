import { describe, expect, it, vi, beforeEach, afterEach } from "vitest";
import { fireEvent, render, screen, within } from "@testing-library/react";
import { HeroSearch } from "@/components/features/home/HeroSearch";
import { SEARCH_EXAMPLES } from "@/lib/mock/search";

const { pushMock } = vi.hoisted(() => ({ pushMock: vi.fn() }));

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: pushMock }),
}));

const SEARCH_INPUT_NAME = "Buscar restaurantes, bares o cafés";

describe("HeroSearch", () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    pushMock.mockReset();
    vi.useRealTimers();
  });

  it("renders the headline and the search input", () => {
    render(<HeroSearch />);

    expect(
      screen.getByRole("heading", { name: /Encontrá dónde comer/ }),
    ).toBeInTheDocument();
    expect(screen.getByRole("textbox", { name: SEARCH_INPUT_NAME })).toBeInTheDocument();
    expect(screen.getByRole("textbox", { name: SEARCH_INPUT_NAME })).toHaveValue("");
  });

  it("navigates to /buscar with the typed query on submit", () => {
    render(<HeroSearch />);

    fireEvent.change(screen.getByRole("textbox", { name: SEARCH_INPUT_NAME }), {
      target: { value: "sushi" },
    });
    fireEvent.click(screen.getByRole("button", { name: /Buscar con IA/ }));

    const expected = new URLSearchParams({ q: "sushi" }).toString();
    expect(pushMock).toHaveBeenCalledWith(`/buscar?${expected}`);
  });

  it("falls back to the current rotating example when the query is left empty", () => {
    render(<HeroSearch />);

    fireEvent.click(screen.getByRole("button", { name: /Buscar con IA/ }));

    const expected = new URLSearchParams({ q: SEARCH_EXAMPLES[0] }).toString();
    expect(pushMock).toHaveBeenCalledWith(`/buscar?${expected}`);
  });

  it("opens a type picker sheet instead of cycling the filter on click", () => {
    render(<HeroSearch />);

    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: /Cualquiera/ }));

    const dialog = screen.getByRole("dialog", { name: "Tipo de lugar" });
    expect(dialog).toBeInTheDocument();
    // Every merchant type (minus "other") is offered as a pickable option.
    expect(within(dialog).getByRole("button", { name: "Café" })).toBeInTheDocument();
    expect(within(dialog).getByRole("button", { name: "Restaurante" })).toBeInTheDocument();
  });

  it("selecting a type in the sheet closes it, updates the trigger label, and is included on submit", () => {
    render(<HeroSearch />);

    fireEvent.click(screen.getByRole("button", { name: /Cualquiera/ }));
    const dialog = screen.getByRole("dialog", { name: "Tipo de lugar" });
    fireEvent.click(within(dialog).getByRole("button", { name: "Café" }));

    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Café/ })).toBeInTheDocument();

    fireEvent.change(screen.getByRole("textbox", { name: SEARCH_INPUT_NAME }), {
      target: { value: "medialunas" },
    });
    fireEvent.click(screen.getByRole("button", { name: /Buscar con IA/ }));

    const expected = new URLSearchParams({ q: "medialunas", type: "cafe" }).toString();
    expect(pushMock).toHaveBeenCalledWith(`/buscar?${expected}`);
  });
});
