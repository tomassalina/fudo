import { describe, expect, it, vi } from "vitest";
import { fireEvent, render, screen } from "@testing-library/react";
import { SearchBar } from "@/components/features/buscar/SearchBar";
import { DEFAULT_BUSCAR_PARAMS } from "@/lib/utils/buscar-href";

// Covers the compact results-page search bar (`isList`'s search row in
// docs/design-reference/Fudo App.dc.html) — a static placeholder, no
// rotation (that behavior lives on the home page's own HeroSearch.tsx), plus
// the clear ("x") button that only shows once the field has text.

const push = vi.fn();
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push }),
}));

describe("SearchBar", () => {
  it("keeps action/method=GET on the form as a no-JS fallback", () => {
    render(<SearchBar defaultValue="" current={DEFAULT_BUSCAR_PARAMS} />);
    const form = screen.getByRole("textbox").closest("form")!;
    expect(form).toHaveAttribute("action", "/buscar");
    expect(form).toHaveAttribute("method", "GET");
    expect(screen.getByRole("textbox")).toHaveAttribute("name", "q");
  });

  it("intercepts submit and pushes a client-side navigation carrying q + current params", () => {
    push.mockClear();
    const current = { ...DEFAULT_BUSCAR_PARAMS, type: "cafe" };
    render(<SearchBar defaultValue="" current={current} />);

    fireEvent.change(screen.getByRole("textbox"), { target: { value: "sushi" } });
    fireEvent.submit(screen.getByRole("textbox").closest("form")!);

    expect(push).toHaveBeenCalledWith("/buscar?q=sushi&type=cafe");
  });

  it("pre-fills the input with defaultValue", () => {
    render(<SearchBar defaultValue="sushi" current={DEFAULT_BUSCAR_PARAMS} />);
    expect(screen.getByRole("textbox")).toHaveValue("sushi");
  });

  it("uses the static isList placeholder by default", () => {
    render(<SearchBar defaultValue="" current={DEFAULT_BUSCAR_PARAMS} />);
    expect(screen.getByRole("textbox")).toHaveAttribute(
      "placeholder",
      "Buscar por nombre, tipo o barrio",
    );
  });

  it("accepts a placeholder override (wide layout)", () => {
    render(
      <SearchBar
        defaultValue=""
        placeholder="Buscar por nombre, plato o barrio"
        current={DEFAULT_BUSCAR_PARAMS}
      />,
    );
    expect(screen.getByRole("textbox")).toHaveAttribute(
      "placeholder",
      "Buscar por nombre, plato o barrio",
    );
  });

  it("hides the clear button when the field is empty", () => {
    render(<SearchBar defaultValue="" current={DEFAULT_BUSCAR_PARAMS} />);
    expect(screen.queryByLabelText("Borrar búsqueda")).not.toBeInTheDocument();
  });

  it("shows the clear button once the field has text, and clears it on click", () => {
    render(<SearchBar defaultValue="sushi" current={DEFAULT_BUSCAR_PARAMS} />);

    const clearButton = screen.getByLabelText("Borrar búsqueda");
    expect(clearButton).toBeInTheDocument();

    fireEvent.click(clearButton);

    expect(screen.getByRole("textbox")).toHaveValue("");
    expect(screen.queryByLabelText("Borrar búsqueda")).not.toBeInTheDocument();
  });

  it("shows the clear button after typing into an initially empty field", () => {
    render(<SearchBar defaultValue="" current={DEFAULT_BUSCAR_PARAMS} />);

    fireEvent.change(screen.getByRole("textbox"), { target: { value: "sushi" } });

    expect(screen.getByLabelText("Borrar búsqueda")).toBeInTheDocument();
  });
});
