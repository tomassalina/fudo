import { describe, expect, it, vi, afterEach } from "vitest";
import { fireEvent, render, screen } from "@testing-library/react";
import { QrSheetContent } from "@/components/features/perfil/QrSheetContent";
import type { Consumer } from "@/lib/session/use-session";

const { useSessionMock } = vi.hoisted(() => ({ useSessionMock: vi.fn() }));

vi.mock("@/lib/session/use-session", () => ({
  useSession: useSessionMock,
}));

const mockConsumer: Consumer = {
  id: "11112222-3333-4444-5555-666677778888",
  firstName: "Martina",
  lastName: "Giménez",
  email: "martina@example.com",
};

describe("QrSheetContent", () => {
  afterEach(() => {
    useSessionMock.mockReset();
  });

  it("shows a login CTA instead of a QR code when logged out", () => {
    useSessionMock.mockReturnValue({ consumer: null, isAuthenticated: false });
    render(<QrSheetContent />);

    expect(
      screen.getByText("Iniciá sesión para ver tu código y sumar visitas."),
    ).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Iniciar sesión" })).toHaveAttribute(
      "href",
      "/login",
    );
    expect(screen.queryByRole("tab", { name: /Mi QR/ })).not.toBeInTheDocument();
  });

  it("defaults to the Escanear tab and can switch to Mi QR", () => {
    useSessionMock.mockReturnValue({ consumer: mockConsumer, isAuthenticated: true });
    render(<QrSheetContent />);

    expect(screen.getByText("Escaneá el QR del local")).toBeInTheDocument();

    fireEvent.click(screen.getByRole("tab", { name: /Mi QR/ }));

    expect(screen.getByText("Martina Giménez")).toBeInTheDocument();
    expect(screen.getByText(/^ID FD-/)).toBeInTheDocument();
  });
});
