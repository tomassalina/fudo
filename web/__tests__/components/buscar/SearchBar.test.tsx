import { describe, expect, it, vi, beforeEach, afterEach } from "vitest";
import { act, render, screen } from "@testing-library/react";
import { SearchBar } from "@/components/buscar/SearchBar";
import { SEARCH_EXAMPLES } from "@/lib/mock/search";

describe("SearchBar", () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

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

  it("starts with the first rotating example as the placeholder", () => {
    render(<SearchBar defaultValue="" />);
    expect(screen.getByRole("textbox")).toHaveAttribute(
      "placeholder",
      SEARCH_EXAMPLES[0],
    );
  });

  it("rotates to the next example every 3 seconds", () => {
    render(<SearchBar defaultValue="" />);

    act(() => {
      vi.advanceTimersByTime(3000);
    });
    expect(screen.getByRole("textbox")).toHaveAttribute(
      "placeholder",
      SEARCH_EXAMPLES[1],
    );

    act(() => {
      vi.advanceTimersByTime(3000);
    });
    expect(screen.getByRole("textbox")).toHaveAttribute(
      "placeholder",
      SEARCH_EXAMPLES[2],
    );
  });

  it("wraps back to the first example after cycling through all of them", () => {
    render(<SearchBar defaultValue="" />);

    act(() => {
      vi.advanceTimersByTime(3000 * SEARCH_EXAMPLES.length);
    });

    expect(screen.getByRole("textbox")).toHaveAttribute(
      "placeholder",
      SEARCH_EXAMPLES[0],
    );
  });

  it("stops rotating after unmount (interval is cleared)", () => {
    const { unmount } = render(<SearchBar defaultValue="" />);
    unmount();

    // If the interval weren't cleared, advancing timers post-unmount would
    // throw or otherwise misbehave when React tries to update an unmounted
    // component's state.
    expect(() => {
      act(() => {
        vi.advanceTimersByTime(3000 * 5);
      });
    }).not.toThrow();
  });
});
