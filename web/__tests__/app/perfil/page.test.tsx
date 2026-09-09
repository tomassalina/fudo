import { describe, expect, it, vi, afterEach } from "vitest";
import { fireEvent, render, screen } from "@testing-library/react";
import type { Consumer } from "@/lib/session/use-session";

const { useSessionMock, replaceMock, pushMock } = vi.hoisted(() => ({
  useSessionMock: vi.fn(),
  replaceMock: vi.fn(),
  pushMock: vi.fn(),
}));

vi.mock("@/lib/session/use-session", () => ({
  useSession: useSessionMock,
}));

vi.mock("next/navigation", () => ({
  useRouter: () => ({ replace: replaceMock, push: pushMock }),
}));

// Imported after the mocks so the page picks them up.
const { default: PerfilPage } = await import("@/app/perfil/page");

const mockConsumer: Consumer = {
  id: "11112222-3333-4444-5555-666677778888",
  firstName: "Martina",
  lastName: "Giménez",
  email: "martina@example.com",
  phone: "+54 9 11 5555 5555",
};

describe("PerfilPage", () => {
  afterEach(() => {
    useSessionMock.mockReset();
    replaceMock.mockReset();
    pushMock.mockReset();
  });

  it("redirects to /login and renders nothing when there is no session", () => {
    useSessionMock.mockReturnValue({
      consumer: null,
      isAuthenticated: false,
      logout: vi.fn(),
      updateProfile: vi.fn(),
    });

    const { container } = render(<PerfilPage />);

    expect(replaceMock).toHaveBeenCalledWith("/login");
    expect(container).toBeEmptyDOMElement();
  });

  it("shows the consumer's profile, visit history and rewards once authenticated", () => {
    useSessionMock.mockReturnValue({
      consumer: mockConsumer,
      isAuthenticated: true,
      logout: vi.fn(),
      updateProfile: vi.fn(),
    });

    render(<PerfilPage />);

    expect(replaceMock).not.toHaveBeenCalled();
    expect(screen.getByText("Martina Giménez")).toBeInTheDocument();
    expect(
      screen.getByRole("heading", { name: "Lugares que visitaste" }),
    ).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Recompensas" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Cerrar sesión/ })).toBeInTheDocument();
  });

  it("logs out and redirects home when the logout action is used", () => {
    const logout = vi.fn();
    useSessionMock.mockReturnValue({
      consumer: mockConsumer,
      isAuthenticated: true,
      logout,
      updateProfile: vi.fn(),
    });

    render(<PerfilPage />);
    fireEvent.click(screen.getByRole("button", { name: /Cerrar sesión/ }));

    expect(logout).toHaveBeenCalled();
    expect(pushMock).toHaveBeenCalledWith("/");
  });

  it("opens the edit-profile sheet and saves changes via updateProfile", () => {
    const updateProfile = vi.fn();
    useSessionMock.mockReturnValue({
      consumer: mockConsumer,
      isAuthenticated: true,
      logout: vi.fn(),
      updateProfile,
    });

    render(<PerfilPage />);
    fireEvent.click(screen.getByRole("button", { name: /Actualizar mis datos/ }));

    expect(screen.getByRole("dialog", { name: "Actualizar mis datos" })).toBeInTheDocument();
    fireEvent.change(screen.getByPlaceholderText("Teléfono"), {
      target: { value: "+54 9 11 4444 4444" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Guardar cambios" }));

    expect(updateProfile).toHaveBeenCalledWith(
      expect.objectContaining({ phone: "+54 9 11 4444 4444" }),
    );
  });
});
