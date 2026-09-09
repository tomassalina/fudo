import { describe, expect, it } from "vitest";
import { fireEvent, render, screen } from "@testing-library/react";
import { SearchBar } from "@/components/features/buscar/SearchBar";

// Covers the compact results-page search bar (`isList`'s search row in
// docs/design-reference/Fudo App.dc.html) — a static placeholder, no
// rotation (that behavior lives on the home page's own HeroSearch.tsx), plus
// the clear ("x") button that only shows once the field has text.

describe("SearchBar", () => {
  it("submits as a plain GET form to /buscar with a `q` field (works without JS)", () => {
    render(<SearchBar defaultValue="" />);
    const form = screen.getByRole("textbox").closest("form")!;
    expect(form).toHaveAttribute("action", "/buscar");
    expect(form).toHaveAttribute("method", "GET");
    expect(screen.getByRole("textbox")).toHaveAttribute("name", "q");
  });

  it("pre-fills the input with defaultValue", () => {
    render(<SearchBar defaultValue="sushi" />);
    expect(screen.getByRole("textbox")).toHaveValue("sushi");
  });

  it("uses the static isList placeholder by default", () => {
    render(<SearchBar defaultValue="" />);
    expect(screen.getByRole("textbox")).toHaveAttribute(
      "placeholder",
      "Buscar por nombre, tipo o barrio",
    );
  });

  it("accepts a placeholder override (wide layout)", () => {
    render(<SearchBar defaultValue="" placeholder="Buscar por nombre, plato o barrio" />);
    expect(screen.getByRole("textbox")).toHaveAttribute(
      "placeholder",
      "Buscar por nombre, plato o barrio",
    );
  });

  it("hides the clear button when the field is empty", () => {
    render(<SearchBar defaultValue="" />);
    expect(screen.queryByLabelText("Borrar búsqueda")).not.toBeInTheDocument();
  });

  it("shows the clear button once the field has text, and clears it on click", () => {
    render(<SearchBar defaultValue="sushi" />);

    const clearButton = screen.getByLabelText("Borrar búsqueda");
    expect(clearButton).toBeInTheDocument();

    fireEvent.click(clearButton);

    expect(screen.getByRole("textbox")).toHaveValue("");
    expect(screen.queryByLabelText("Borrar búsqueda")).not.toBeInTheDocument();
  });

  it("shows the clear button after typing into an initially empty field", () => {
    render(<SearchBar defaultValue="" />);

    fireEvent.change(screen.getByRole("textbox"), { target: { value: "sushi" } });

    expect(screen.getByLabelText("Borrar búsqueda")).toBeInTheDocument();
  });
});
