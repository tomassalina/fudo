import { describe, expect, it, vi, afterEach } from "vitest";
import { render, screen } from "@testing-library/react";

const { useSessionMock } = vi.hoisted(() => ({
  useSessionMock: vi.fn(),
}));

vi.mock("@/lib/session/use-session", () => ({
  useSession: useSessionMock,
}));

// Imported after the mock so the component picks it up.
const { DetailTabs } = await import("@/components/features/restaurantes/DetailTabs");

describe("DetailTabs", () => {
  afterEach(() => {
    useSessionMock.mockReset();
  });

  it('labels the loyalty tab "Recompensas" when logged out', () => {
    useSessionMock.mockReturnValue({ isAuthenticated: false });

    render(<DetailTabs loyaltySection={<div />} menuSection={<div />} />);

    expect(screen.getByRole("button", { name: /Recompensas/ })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Mis visitas/ })).not.toBeInTheDocument();
  });

  it('labels the loyalty tab "Mis visitas" when authenticated', () => {
    useSessionMock.mockReturnValue({ isAuthenticated: true });

    render(<DetailTabs loyaltySection={<div />} menuSection={<div />} />);

    expect(screen.getByRole("button", { name: /Mis visitas/ })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Recompensas/ })).not.toBeInTheDocument();
  });
});
