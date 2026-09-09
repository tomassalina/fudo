import { describe, expect, it, vi, afterEach } from "vitest";
import { render, screen } from "@testing-library/react";

const { useSessionMock, useIsPhoneViewportMock } = vi.hoisted(() => ({
  useSessionMock: vi.fn(),
  useIsPhoneViewportMock: vi.fn(),
}));

vi.mock("@/lib/session/use-session", () => ({
  useSession: useSessionMock,
}));

vi.mock("@/lib/hooks/use-viewport", () => ({
  useIsPhoneViewport: useIsPhoneViewportMock,
}));

const { Header } = await import("@/components/layout/Header");

describe("Header", () => {
  afterEach(() => {
    useSessionMock.mockReset();
    useIsPhoneViewportMock.mockReset();
  });

  it("renders nothing at wide viewports — WideNav owns that chrome instead", () => {
    useIsPhoneViewportMock.mockReturnValue(false);
    useSessionMock.mockReturnValue({ isAuthenticated: false });

    const { container } = render(<Header />);

    expect(container).toBeEmptyDOMElement();
  });

  it("shows the 'Iniciar sesión' link on phone when logged out", () => {
    useIsPhoneViewportMock.mockReturnValue(true);
    useSessionMock.mockReturnValue({ isAuthenticated: false });

    render(<Header />);

    expect(screen.getByRole("link", { name: "Iniciar sesión" })).toHaveAttribute(
      "href",
      "/login",
    );
  });

  it("hides the 'Iniciar sesión' link on phone once authenticated", () => {
    useIsPhoneViewportMock.mockReturnValue(true);
    useSessionMock.mockReturnValue({ isAuthenticated: true });

    render(<Header />);

    expect(
      screen.queryByRole("link", { name: "Iniciar sesión" }),
    ).not.toBeInTheDocument();
  });
});
