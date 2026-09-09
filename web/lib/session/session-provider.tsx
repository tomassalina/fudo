"use client";

import {
  createContext,
  useCallback,
  useMemo,
  useSyncExternalStore,
  type ReactNode,
} from "react";
import {
  login as apiLogin,
  register as apiRegister,
  ApiError,
  type RawConsumer,
  type RegisterInput,
  type RegistrationErrorBody,
  type SessionErrorBody,
} from "@/lib/api/auth";
import {
  clearStoredToken,
  getStoredToken,
  setStoredToken,
} from "@/lib/auth/token-storage";

// Mirrors `public.consumers` (backend/db/structure.sql) field-for-field
// where it makes sense for a client-side session — id/firstName/lastName/
// email/phone map 1:1 to the real columns (camelCased). `password_hash`,
// `dni_encrypted`/`dni_bidx` and the audit columns are backend-only and
// never belong on the client.
//
// `dni` and `createdAt` are kept as optional fields for parity with the
// design's profile view (`"•••• 4821"`, "Alta") but — now that this session
// is backed by the real `ConsumerBlueprint`
// (backend/app/blueprints/consumer_blueprint.rb) — neither is ever actually
// populated: that blueprint deliberately excludes `dni` (encrypted PII) and
// every audit column from both `POST /api/v1/sessions` and
// `POST /api/v1/registrations` responses (confirmed by curling both live).
// SettingsTab already renders sensible fallbacks for both ("Pendiente" /
// "—"), so this is a known, harmless gap, not a bug — see mapRawConsumer
// below.
export interface Consumer {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  phone?: string;
  dni?: string;
  createdAt?: string;
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

/**
 * What RegisterForm actually collects. No `dni` (per design.md Decision 1 —
 * see RegisterForm's doc comment) and no password-confirmation field
 * either: `has_secure_password`'s confirmation check
 * (`Consumer#password_confirmation`) only runs when that param is present
 * at all — confirmed live, `POST /api/v1/registrations` with no
 * `password_confirmation` key succeeds — so there's nothing for a second
 * password input to validate against here.
 */
export interface ConsumerRegistration {
  email: string;
  password: string;
  firstName: string;
  lastName: string;
  phone: string;
}

export interface SessionContextValue {
  consumer: Consumer | null;
  isAuthenticated: boolean;
  /** Real login against `POST /api/v1/sessions`. Throws an `Error` with a
   * Spanish, user-facing message on invalid credentials or a network
   * failure — callers (LoginForm) should catch it and render
   * `error.message` as-is. */
  login: (email: string, password: string) => Promise<void>;
  /** Real signup against `POST /api/v1/registrations`. Same error contract
   * as `login`. */
  register: (input: ConsumerRegistration) => Promise<void>;
  logout: () => void;
  /**
   * Edits the *local* session copy only — merges `patch` into the current
   * consumer and persists it, same localStorage-backed store as
   * `login`/`register`/`logout`. This is NOT a real backend call: unlike
   * favorites and consumer_settings, there is no `PATCH /api/v1/consumers/:id`
   * (or `/consumers/me`) route anywhere in `backend/config/routes.rb` —
   * confirmed absent, not just unauthenticated. "Actualizar mis datos"
   * (EditProfileForm) therefore only ever updates what this tab of the
   * browser shows; it does not persist across devices or survive the
   * backend re-issuing a session from its own data. Revisit this once that
   * endpoint exists.
   * No-op (besides being a stable function reference) when called while
   * logged out.
   */
  updateProfile: (patch: ConsumerUpdateInput) => void;
}

export const SessionContext = createContext<SessionContextValue | null>(null);

const SESSION_STORAGE_KEY = "fudo:consumer-session";

// --- External store -------------------------------------------------------
//
// Session state lives outside React (module-level) and is read via
// `useSyncExternalStore` — the same pattern `lib/hooks/use-viewport.ts`
// already uses for "external browser state that must not cause a
// server/client hydration mismatch". `getServerSnapshot` always returns
// `null` (server and first client paint render logged-out); the real value,
// if any, is read from `localStorage` the first time `getSnapshot` runs on
// the client and then kept in sync by `login`/`register`/`logout`.
//
// IMPORTANT — see lib/session/use-require-auth.ts for why no component
// should redirect off `isAuthenticated` directly inside a plain
// `useEffect`: the very first client render legitimately reports
// `isAuthenticated: false` (it has to, to match the server-rendered HTML)
// even when a valid session exists in localStorage, and a redirect effect
// with no extra guard fires on exactly that transient false value — this
// was the root cause of the `/perfil` hard-reload bug (see that file's
// header comment for the full mechanics, confirmed with a hydration
// reproduction test).
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
    // A session needs BOTH halves to count as logged in — a leftover
    // consumer blob with no token (e.g. `logout()` failed to clear one but
    // not the other because storage got blocked mid-write) must not report
    // as authenticated: every protected call would omit the Authorization
    // header and 401 anyway, so treating it as logged out here is more
    // honest than showing a session that can't actually call anything.
    const token = getStoredToken();
    if (!token) return null;

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

/** Sets both halves of the session (consumer + token) atomically, or clears
 * both on logout. `token` is required whenever `next` is non-null — there is
 * no such thing as a consumer without a token in this store, see
 * `readStoredConsumer` above. */
function setSessionState(next: Consumer | null, token?: string) {
  consumerState = next;
  hydratedFromStorage = true;
  if (next) {
    window.localStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(next));
    if (token) setStoredToken(token);
  } else {
    window.localStorage.removeItem(SESSION_STORAGE_KEY);
    clearStoredToken();
  }
  notify();
}

/**
 * Plain (non-hook) session clear — the same effect as `useSession().logout`,
 * but callable from outside a component. Exists specifically for protected
 * API clients (lib/api/favorites.ts, lib/api/consumer-settings.ts) that get
 * a `401` back from an expired/invalid token: they call this directly
 * (favorites-store.ts's `handleFavoriteError`,
 * use-notifications-setting.ts's rejection handlers) instead of needing a
 * hook,
 * which flips `isAuthenticated` to `false` everywhere `useSession()` is
 * read — `useRequireAuth()` (lib/session/use-require-auth.ts) then redirects
 * to `/login` from any page that requires a session, with no extra plumbing
 * needed at each protected call site beyond "on 401, call this".
 */
export function forceLogout(): void {
  setSessionState(null);
}

/**
 * Plain (non-hook) subscription to session changes — for module-level
 * stores outside React that need to react to login/register/logout/
 * forceLogout (favorites-store.ts is the current user: without this, a
 * `FavoriteButton` mounted on e.g. `/buscar` — not gated by
 * `useRequireAuth()` — kept showing its last-known heart state after a
 * forced logout, since nothing told its independent `useSyncExternalStore`
 * to resync). Returns an unsubscribe function, same contract as
 * `useSyncExternalStore`'s `subscribe`.
 */
export function subscribeToSession(listener: Listener): () => void {
  return subscribe(listener);
}

function mapRawConsumer(raw: RawConsumer): Consumer {
  return {
    id: raw.id,
    firstName: raw.first_name,
    lastName: raw.last_name,
    email: raw.email,
    phone: raw.phone ?? undefined,
    // dni/createdAt: never present on ConsumerBlueprint — see the doc
    // comment on `Consumer` above.
  };
}

/** Backend-provided message for a failed login, or a sensible Spanish
 * fallback — matches LoginForm/RegisterForm's existing user-facing
 * copy convention (see those files). */
function loginErrorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.status === 401) {
      // sessions_controller.rb's #create is deliberately generic (doesn't
      // reveal whether the email exists) — mirror that instead of a more
      // specific message we'd have to invent.
      return "Email o contraseña incorrectos.";
    }
    if (error.status === undefined) {
      return "No pudimos conectarnos con Fudo. Probá de nuevo en unos segundos.";
    }
  }
  return "Ocurrió un error al iniciar sesión. Intentá de nuevo.";
}

/** Same idea as {@link loginErrorMessage}, for registration's validation
 * shape (`{ errors: { field: ["message", ...] } }`, confirmed by curling
 * `POST /api/v1/registrations` live — see lib/api/auth.ts). */
function registerErrorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.status === 422) {
      const body = error.body as RegistrationErrorBody | undefined;
      const errors = body?.errors ?? {};
      if (errors.email) return "Ese email ya está registrado.";
      if (errors.password_confirmation) return "Las contraseñas no coinciden.";
      // Covers every other backend validation (e.g. `dni` — RegisterForm
      // doesn't collect it yet, see ConsumerRegistration's doc comment)
      // without hardcoding a message for a field this form doesn't even
      // show.
      return "No pudimos completar el registro. Revisá tus datos e intentá de nuevo.";
    }
    if (error.status === undefined) {
      return "No pudimos conectarnos con Fudo. Probá de nuevo en unos segundos.";
    }
  }
  return "Ocurrió un error al crear tu cuenta. Intentá de nuevo.";
}

/**
 * Real session provider — owns the single source of truth for "is there a
 * logged-in consumer" the rest of the app (AppNav, LoginForm, RegisterForm,
 * RegalarPage, ...) reads via `useSession()` (lib/session/use-session.ts).
 * Mounted once in app/layout.tsx.
 *
 * Backed by the real `POST /api/v1/sessions` / `POST /api/v1/registrations`
 * endpoints (lib/api/auth.ts) and a persisted JWT (lib/auth/token-storage.ts)
 * — replaces the earlier localStorage-only mock (no backend call at all)
 * that a prior session built. `login`/`register`/`logout`/`isAuthenticated`
 * keep the exact same shape existing consumers (AppNav, Perfil, Regalar,
 * FavoritesTab, ...) already read; this is an internal swap of what backs
 * them, not an API redesign — `register` is the one addition, since the old
 * mock reused `login` (with an optional `profile` override) to fake signup,
 * which real auth has no equivalent for.
 */
export function SessionProvider({ children }: { children: ReactNode }) {
  const consumer = useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);

  const login = useCallback(async (email: string, password: string) => {
    try {
      const response = await apiLogin({ email, password });
      setSessionState(mapRawConsumer(response.consumer), response.token);
    } catch (error) {
      throw new Error(loginErrorMessage(error));
    }
  }, []);

  const register = useCallback(async (input: ConsumerRegistration) => {
    const payload: RegisterInput = {
      email: input.email,
      password: input.password,
      first_name: input.firstName,
      last_name: input.lastName,
      phone: input.phone,
    };
    try {
      const response = await apiRegister(payload);
      setSessionState(mapRawConsumer(response.consumer), response.token);
    } catch (error) {
      throw new Error(registerErrorMessage(error));
    }
  }, []);

  // The backend issues stateless JWTs (backend/app/lib/json_web_token.rb,
  // 30-day expiration) with no server-side session/blocklist — there is no
  // `DELETE /api/v1/sessions` or equivalent revocation route anywhere in
  // `backend/config/routes.rb` (confirmed absent). So "logging out" can only
  // ever mean clearing the token client-side; the token itself stays
  // technically valid (and would still work if replayed) until it expires
  // on its own. That's the correct behavior for this backend, not a
  // shortcut — there's no server-side state to also invalidate.
  const logout = useCallback(() => forceLogout(), []);

  const updateProfile = useCallback((patch: ConsumerUpdateInput) => {
    // Local-only — see the doc comment on `updateProfile` in
    // SessionContextValue above for why there's no real endpoint to call.
    // No `token` argument: the existing token in storage is left untouched,
    // only the cached consumer JSON changes.
    if (consumerState === null) return;
    setSessionState({ ...consumerState, ...patch });
  }, []);

  const value = useMemo<SessionContextValue>(
    () => ({
      consumer,
      isAuthenticated: consumer !== null,
      login,
      register,
      logout,
      updateProfile,
    }),
    [consumer, login, register, logout, updateProfile],
  );

  return (
    <SessionContext.Provider value={value}>{children}</SessionContext.Provider>
  );
}

export type { RawConsumer, SessionErrorBody };
