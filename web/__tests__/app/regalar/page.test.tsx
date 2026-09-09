import { describe, expect, it, vi, afterEach } from "vitest";
import { fireEvent, render, screen } from "@testing-library/react";

const { useSessionMock } = vi.hoisted(() => ({
  useSessionMock: vi.fn(),
}));

vi.mock("@/lib/session/use-session", () => ({
  useSession: useSessionMock,
}));

// Imported after the mock so the page picks it up.
const { default: RegalarPage } = await import("@/app/regalar/page");

describe("RegalarPage", () => {
  afterEach(() => {
    useSessionMock.mockReset();
  });

  it("shows the tier picker and the login-required card when there is no session", () => {
    useSessionMock.mockReturnValue({ isAuthenticated: false });
    render(<RegalarPage />);

    expect(screen.getByRole("heading", { name: "Regalar" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /CLASSIC/ })).toBeInTheDocument();
    expect(
      screen.getByText("Iniciá sesión para comprar una gift card"),
    ).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Iniciar sesión" })).toHaveAttribute(
      "href",
      "/perfil",
    );
    // The checkout form (recipient phone) must not render while logged out.
    expect(
      screen.queryByPlaceholderText("Teléfono del destinatario"),
    ).not.toBeInTheDocument();
  });

  it("shows the checkout form instead of the login card once authenticated", () => {
    useSessionMock.mockReturnValue({ isAuthenticated: true });
    render(<RegalarPage />);

    expect(
      screen.queryByText("Iniciá sesión para comprar una gift card"),
    ).not.toBeInTheDocument();
    expect(screen.getByPlaceholderText("Teléfono del destinatario")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Comprar y enviar/ })).toBeInTheDocument();
  });

  it("keeps the buy button disabled on the custom tier until a valid amount is entered", () => {
    useSessionMock.mockReturnValue({ isAuthenticated: true });
    render(<RegalarPage />);

    fireEvent.click(screen.getByRole("button", { name: /PLATINUM/ }));
    expect(screen.getByRole("button", { name: "Ingresá un monto" })).toBeDisabled();

    fireEvent.change(screen.getByLabelText("Monto de la gift card"), {
      target: { value: "300000" },
    });
    expect(
      screen.getByRole("button", { name: "Comprar y enviar $300.000" }),
    ).not.toBeDisabled();
  });

  it("completes the purchase flow and can start a new gift after resetting", () => {
    useSessionMock.mockReturnValue({ isAuthenticated: true });
    render(<RegalarPage />);

    fireEvent.change(screen.getByPlaceholderText("Teléfono del destinatario"), {
      target: { value: "+54 9 11 5555 5555" },
    });
    fireEvent.click(screen.getByRole("button", { name: /Comprar y enviar/ }));

    expect(screen.getByText("¡Gift card enviada!")).toBeInTheDocument();
    expect(screen.getByText("Enviada a +54 9 11 5555 5555")).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Regalar otra" }));
    expect(screen.getByPlaceholderText("Teléfono del destinatario")).toHaveValue("");
  });
});
