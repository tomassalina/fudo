// Typed fetch wrapper for the real Rails backend (`/api/v1/*`, see PLAN.md
// Fase 3). Confirmed live and exercised end-to-end against a running
// localhost:3000 (merchants/menu-items originally, and now real auth +
// protected endpoints — see ./README.md and lib/api/auth.ts). See
// ./README.md for the feature-flag mechanism and its rationale.

const BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ?? "";

// `POST /api/v1/registrations` and `POST /api/v1/sessions` (email +
// password login, JWT/session token) are now implemented for real — see
// lib/api/auth.ts and lib/session/session-provider.tsx. This app's auth was
// originally out of scope (see ./README.md's now-superseded "Out of scope:
// auth" section, kept for history) but a prior session already added a
// mocked, localStorage-only session; this one replaces that mock with real
// backend calls.

/** How long a real API call may hang before we treat the backend as
 * unreachable and surface a network error. Doubles as the "cheap
 * reachability signal" from PLAN.md Fase 4: a slow/dead backend fails fast
 * instead of hanging the request or the build. */
const REQUEST_TIMEOUT_MS = 5000;

export class ApiError extends Error {
  /** HTTP status code, when the backend answered but with a non-2xx status.
   * Absent for network-level failures (unreachable host, timeout, DNS). */
  status?: number;

  /**
   * Parsed JSON error body, when the backend answered with one (e.g.
   * `{ error: "Invalid email or password" }` from sessions#create, or
   * `{ errors: { email: ["has already been taken"] } }` from
   * registrations#create — both confirmed by curling the live backend, see
   * lib/api/auth.ts). `undefined` when the response had no JSON body, or a
   * body that failed to parse. Callers that need to surface a specific
   * backend-provided message (auth flows) should read this instead of
   * re-parsing the response themselves; every other caller can keep
   * ignoring it and just catching `ApiError`.
   */
  body?: unknown;

  constructor(
    message: string,
    options?: { status?: number; cause?: unknown; body?: unknown },
  ) {
    super(message, { cause: options?.cause });
    this.name = "ApiError";
    this.status = options?.status;
    this.body = options?.body;
  }
}

/** Whether `NEXT_PUBLIC_API_BASE_URL` is set, i.e. whether callers should
 * attempt the real backend at all. See ./README.md — this is a hard switch,
 * not a "try real, fall back to mock" mechanism. */
export function isApiConfigured(): boolean {
  return BASE_URL.length > 0;
}

export async function apiFetch<T>(
  path: string,
  init?: RequestInit,
): Promise<T> {
  let response: Response;

  try {
    response = await fetch(`${BASE_URL}${path}`, {
      ...init,
      signal: init?.signal ?? AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
  } catch (cause) {
    // Network failure, DNS failure, or the timeout above firing.
    throw new ApiError(`No se pudo conectar con la API (${path})`, {
      cause,
    });
  }

  if (!response.ok) {
    // Best-effort: most error responses on this API are JSON
    // (`{ error: "..." }` or `{ errors: {...} }`, see ApiError#body's doc
    // comment), but this must never throw on a non-JSON or empty body.
    const body = await response.json().catch(() => undefined);
    throw new ApiError(`API request failed: ${response.status} ${path}`, {
      status: response.status,
      body,
    });
  }

  // 204 No Content (e.g. DELETE /favorites/:id, DELETE /consumer_settings/:id)
  // has no body — `.json()` on an empty body throws a SyntaxError. Every
  // caller of a 204 endpoint expects `Promise<void>` anyway.
  if (response.status === 204) {
    return undefined as T;
  }

  return response.json() as Promise<T>;
}
