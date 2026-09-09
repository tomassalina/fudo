"use client";

import {
  createContext,
  useCallback,
  useMemo,
  useSyncExternalStore,
  type ReactNode,
} from "react";

// Mirrors `public.consumers` (backend/db/structure.sql) field-for-field
// where it makes sense for a client-side session — id/firstName/lastName/
// email/phone map 1:1 to the real columns (camelCased, per the task brief
// for this session shape). `password_hash`, `dni_encrypted`/`dni_bidx` and
// the audit columns are backend-only and never belong on the client; `dni`
// is kept as an optional display field for parity with the design's profile
// view (`"•••• 4821"`), but nothing in this mock flow ever collects it — per
// design.md Decision 1, the DNI is loaded by the waiter at checkout, not by
// the consumer at signup, so RegisterForm intentionally has no DNI field.
export interface Consumer {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  phone?: string;
  dni?: string;
}

export type ConsumerProfileInput = Partial<
  Pick<Consumer, "firstName" | "lastName" | "phone">
>;

/** Editable fields from the Perfil "Actualizar mis datos" sheet — a superset
 * of {@link ConsumerProfileInput} (adds `email`, not collected at
 * login/registro time but editable afterwards per the design reference's
 * `eEmail` field). */
export type ConsumerUpdateInput = Partial<
  Pick<Consumer, "firstName" | "lastName" | "email" | "phone">
>;

export interface SessionContextValue {
  consumer: Consumer | null;
  isAuthenticated: boolean;
  /**
   * Mock login — see the TODO below. `profile` is an optional extension used
   * by RegisterForm so "registering" can seed the mocked consumer with the
   * name/phone the person actually typed, while LoginForm keeps calling this
   * with just `(email, password)` per the brief.
   */
  login: (
    email: string,
    password: string,
    profile?: ConsumerProfileInput,
  ) => Promise<void>;
  logout: () => void;
  /**
   * Mock profile edit for the Perfil "Actualizar mis datos" sheet — merges
   * `patch` into the current consumer and persists it, same
   * localStorage-backed store as `login`/`logout`. Unlike `login`, this never
   * mints a new `id`: it's an edit of the existing session, not a new one.
   * No-op (besides being a stable function reference) when called while
   * logged out.
   */
  updateProfile: (patch: ConsumerUpdateInput) => void;
}

export const SessionContext = createContext<SessionContextValue | null>(null);

const SESSION_STORAGE_KEY = "fudo:consumer-session";

// Mock "network" delay so the loading state in LoginForm/RegisterForm is
// actually visible instead of resolving on the same tick.
const MOCK_LOGIN_DELAY_MS = 500;

// --- External store -------------------------------------------------------
//
// Session state lives outside React (module-level) and is read via
// `useSyncExternalStore` — the same pattern `lib/hooks/use-viewport.ts`
// already uses for "external browser state that must not cause a
// server/client hydration mismatch". `getServerSnapshot` always returns
// `null` (server and first client paint render logged-out); the real value,
// if any, is read from `localStorage` the first time `getSnapshot` runs on
// the client and then kept in sync by `login`/`logout`. This is deliberate
// instead of `useEffect` + `setState` (which reads the exact same way but
// causes an extra render pass react-hooks/set-state-in-effect flags).
type Listener = () => void;

let consumerState: Consumer | null = null;
let hydratedFromStorage = false;
const listeners = new Set<Listener>();

function notify() {
  for (const listener of listeners) listener();
}

function subscribe(listener: Listener) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function readStoredConsumer(): Consumer | null {
  try {
    const raw = window.localStorage.getItem(SESSION_STORAGE_KEY);
    return raw ? (JSON.parse(raw) as Consumer) : null;
  } catch {
    // Corrupted or blocked storage (private mode, quota) — fall back to
    // logged-out instead of throwing during render.
    return null;
  }
}

function getSnapshot(): Consumer | null {
  if (!hydratedFromStorage) {
    consumerState = readStoredConsumer();
    hydratedFromStorage = true;
  }
  return consumerState;
}

function getServerSnapshot(): Consumer | null {
  return null;
}

function setConsumerState(next: Consumer | null) {
  consumerState = next;
  hydratedFromStorage = true;
  if (next) {
    window.localStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(next));
  } else {
    window.localStorage.removeItem(SESSION_STORAGE_KEY);
  }
  notify();
}

/** Turns "martina.gimenez@gmail.com" into { firstName: "Martina", lastName: "Gimenez" } — best-effort only, used when no explicit profile is supplied (plain login, not registration). */
function deriveNameFromEmail(email: string): Pick<Consumer, "firstName" | "lastName"> {
  const capitalize = (value: string) =>
    value.length > 0 ? value[0].toUpperCase() + value.slice(1) : value;

  const [local] = email.split("@");
  const parts = (local ?? "")
    .split(/[.\-_]+/)
    .map((part) => part.trim())
    .filter(Boolean);

  return {
    firstName: capitalize(parts[0] ?? "Consumidor"),
    lastName: capitalize(parts.slice(1).join(" ")) || "Fudo",
  };
}

/**
 * Mocked-but-real session provider — owns the single source of truth for
 * "is there a logged-in consumer" the rest of the app (AppNav, LoginForm,
 * RegisterForm, RegalarPage, ...) reads via `useSession()`
 * (lib/session/use-session.ts). Mounted once in app/layout.tsx.
 */
export function SessionProvider({ children }: { children: ReactNode }) {
  const consumer = useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);

  const login = useCallback(
    async (email: string, _password: string, profile?: ConsumerProfileInput) => {
      // TODO: reemplazar por auth real contra /api/v1/sessions en la fase de integración backend.
      // Mock: no hay backend que valide credenciales — cualquier
      // email con formato válido + password no vacía "loguea" (la validación
      // de formato vive en LoginForm/RegisterForm). El nombre se deriva del
      // email salvo que se pase `profile` explícito (RegisterForm, con lo
      // que la persona tipeó en el formulario).
      await new Promise((resolve) => setTimeout(resolve, MOCK_LOGIN_DELAY_MS));

      const derived = deriveNameFromEmail(email);
      setConsumerState({
        id: crypto.randomUUID(),
        firstName: profile?.firstName || derived.firstName,
        lastName: profile?.lastName || derived.lastName,
        email,
        phone: profile?.phone,
      });
    },
    [],
  );

  const logout = useCallback(() => setConsumerState(null), []);

  const updateProfile = useCallback((patch: ConsumerUpdateInput) => {
    // TODO: reemplazar por PATCH /api/v1/consumers/me real en la fase de integración backend.
    if (consumerState === null) return;
    setConsumerState({ ...consumerState, ...patch });
  }, []);

  const value = useMemo<SessionContextValue>(
    () => ({
      consumer,
      isAuthenticated: consumer !== null,
      login,
      logout,
      updateProfile,
    }),
    [consumer, login, logout, updateProfile],
  );

  return (
    <SessionContext.Provider value={value}>{children}</SessionContext.Provider>
  );
}
