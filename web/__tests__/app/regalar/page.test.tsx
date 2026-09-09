import { describe, expect, it, vi, afterEach } from "vitest";
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { ApiError } from "@/lib/api/client";

const { useSessionMock, createGiftMock, forceLogoutMock } = vi.hoisted(() => ({
  useSessionMock: vi.fn(),
  createGiftMock: vi.fn(),
  forceLogoutMock: vi.fn(),
}));

vi.mock("@/lib/session/use-session", () => ({
  useSession: useSessionMock,
}));

// RegalarPage's checkout now calls the real `POST /api/v1/gifts` (via
// lib/gift/use-gift-purchase.ts) — mock the API client and `forceLogout`,
// same pattern as __tests__/lib/gift/use-gift-purchase.test.ts.
vi.mock("@/lib/api/gifts", async () => {
  const actual = await vi.importActual<typeof import("@/lib/api/gifts")>(
    "@/lib/api/gifts",
  );
  return { ...actual, createGift: createGiftMock };
});

vi.mock("@/lib/session/session-provider", () => ({
  forceLogout: forceLogoutMock,
}));

// Imported after the mocks so the page picks them up.
const { default: RegalarPage } = await import("@/app/regalar/page");

describe("RegalarPage", () => {
  afterEach(() => {
    useSessionMock.mockReset();
    createGiftMock.mockReset();
    forceLogoutMock.mockReset();
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

  it("completes the purchase flow against the real gifts API and can start a new gift after resetting", async () => {
    createGiftMock.mockResolvedValue({ id: 129, status: "pending" });
    useSessionMock.mockReturnValue({ isAuthenticated: true });
    render(<RegalarPage />);

    fireEvent.change(screen.getByPlaceholderText("Teléfono del destinatario"), {
      target: { value: "+54 9 11 5555 5555" },
    });
    fireEvent.click(screen.getByRole("button", { name: /Comprar y enviar/ }));

    await waitFor(() =>
      expect(screen.getByText("¡Gift card enviada!")).toBeInTheDocument(),
    );
    expect(screen.getByText("Enviada a +54 9 11 5555 5555")).toBeInTheDocument();
    // Real data from the backend response, not a canned message.
    expect(screen.getByText("Comprobante Nº 129")).toBeInTheDocument();
    expect(createGiftMock).toHaveBeenCalledWith(
      expect.objectContaining({
        type: "classic",
        amount: 12_000,
        recipient_phone: "+54 9 11 5555 5555",
      }),
    );

    fireEvent.click(screen.getByRole("button", { name: "Regalar otra" }));
    expect(screen.getByPlaceholderText("Teléfono del destinatario")).toHaveValue("");
  });

  it("shows the backend's validation error instead of a fake success", async () => {
    createGiftMock.mockRejectedValue(
      new ApiError("API request failed", {
        status: 422,
        body: { errors: { recipient_phone: ["can't be blank"] } },
      }),
    );
    useSessionMock.mockReturnValue({ isAuthenticated: true });
    render(<RegalarPage />);

    fireEvent.click(screen.getByRole("button", { name: /Comprar y enviar/ }));

    await waitFor(() =>
      expect(
        screen.getByText("Ingresá un teléfono de destinatario válido."),
      ).toBeInTheDocument(),
    );
    expect(screen.queryByText("¡Gift card enviada!")).not.toBeInTheDocument();
  });
});
