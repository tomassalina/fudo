import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { FilterFields } from "@/components/features/buscar/FilterFields";
import { DEFAULT_BUSCAR_PARAMS } from "@/lib/utils/buscar-href";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn() }),
}));

describe("FilterFields", () => {
  it('hides the "Ocultar visitados" checkbox when logged out', () => {
    render(
      <FilterFields
        current={DEFAULT_BUSCAR_PARAMS}
        activeType={null}
        availableTypes={[]}
        availableHoods={[]}
        isAuthenticated={false}
      />,
    );

    expect(screen.queryByRole("checkbox", { name: /Ocultar visitados/ })).not.toBeInTheDocument();
  });

  it('shows the "Ocultar visitados" checkbox when authenticated', () => {
    render(
      <FilterFields
        current={DEFAULT_BUSCAR_PARAMS}
        activeType={null}
        availableTypes={[]}
        availableHoods={[]}
        isAuthenticated={true}
      />,
    );

    expect(screen.getByRole("checkbox", { name: /Ocultar visitados/ })).toBeInTheDocument();
  });
});
