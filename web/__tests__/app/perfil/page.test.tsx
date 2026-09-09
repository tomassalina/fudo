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
  createdAt: "2025-03-12T00:00:00.000Z",
};

function goToTab(name: RegExp | string) {
  fireEvent.click(screen.getByRole("tab", { name }));
}

describe("PerfilPage", () => {
  afterEach(() => {
    useSessionMock.mockReset();
    replaceMock.mockReset();
    pushMock.mockReset();
    window.localStorage.clear();
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

  it("shows the consumer's profile, the segmented control and the Visitas tab by default", () => {
    useSessionMock.mockReturnValue({
      consumer: mockConsumer,
      isAuthenticated: true,
      logout: vi.fn(),
      updateProfile: vi.fn(),
    });

    render(<PerfilPage />);

    expect(replaceMock).not.toHaveBeenCalled();
    expect(screen.getByText("Martina Giménez")).toBeInTheDocument();
    expect(screen.getByRole("tablist", { name: /Secciones de tu perfil/ })).toBeInTheDocument();
    expect(screen.getByRole("tab", { name: /Visitas/ })).toHaveAttribute("aria-selected", "true");
    expect(
      screen.getByRole("heading", { name: "Lugares que visitaste" }),
    ).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Recompensas" })).toBeInTheDocument();
  });

  it("switches to Favoritos and shows the empty state when nothing is favorited", () => {
    useSessionMock.mockReturnValue({
      consumer: mockConsumer,
      isAuthenticated: true,
      logout: vi.fn(),
      updateProfile: vi.fn(),
    });

    render(<PerfilPage />);
    goToTab(/Favoritos/);

    expect(screen.getByRole("tab", { name: /Favoritos/ })).toHaveAttribute(
      "aria-selected",
      "true",
    );
    expect(
      screen.getByText("Marcá lugares con el corazón y aparecen acá."),
    ).toBeInTheDocument();
  });

  it("switches to Ajustes and shows the personal data rows", () => {
    useSessionMock.mockReturnValue({
      consumer: mockConsumer,
      isAuthenticated: true,
      logout: vi.fn(),
      updateProfile: vi.fn(),
    });

    render(<PerfilPage />);
    goToTab(/Ajustes/);

    expect(screen.getByText("Nombre")).toBeInTheDocument();
    expect(screen.getAllByText("martina@example.com").length).toBeGreaterThan(0);
    expect(screen.getByText("+54 9 11 5555 5555")).toBeInTheDocument();
    expect(screen.getAllByText("Pendiente").length).toBeGreaterThan(0); // no DNI on file
    expect(screen.getByRole("button", { name: /Cerrar sesión/ })).toBeInTheDocument();
  });

  it("logs out and redirects home from the Ajustes tab", () => {
    const logout = vi.fn();
    useSessionMock.mockReturnValue({
      consumer: mockConsumer,
      isAuthenticated: true,
      logout,
      updateProfile: vi.fn(),
    });

    render(<PerfilPage />);
    goToTab(/Ajustes/);
    fireEvent.click(screen.getByRole("button", { name: /Cerrar sesión/ }));

    expect(logout).toHaveBeenCalled();
    expect(pushMock).toHaveBeenCalledWith("/");
  });

  it("opens the edit-profile sheet from Ajustes and saves changes via updateProfile", () => {
    const updateProfile = vi.fn();
    useSessionMock.mockReturnValue({
      consumer: mockConsumer,
      isAuthenticated: true,
      logout: vi.fn(),
      updateProfile,
    });

    render(<PerfilPage />);
    goToTab(/Ajustes/);
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

  it("arms and blocks account deletion without ever calling logout (no real endpoint yet)", () => {
    const logout = vi.fn();
    useSessionMock.mockReturnValue({
      consumer: mockConsumer,
      isAuthenticated: true,
      logout,
      updateProfile: vi.fn(),
    });

    render(<PerfilPage />);
    goToTab(/Ajustes/);

    const deleteButton = screen.getByRole("button", { name: "Eliminar mi cuenta" });
    fireEvent.click(deleteButton);
    expect(screen.getByRole("button", { name: /Tocá de nuevo para confirmar/ })).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: /Tocá de nuevo para confirmar/ }));
    expect(
      screen.getByRole("button", { name: /Pendiente de backend/ }),
    ).toBeInTheDocument();
    expect(logout).not.toHaveBeenCalled();
  });
});
