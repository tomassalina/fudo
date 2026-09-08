// Typed fetch wrapper for the real Rails backend (`/api/v1/*`, see PLAN.md
// Fase 3). The backend does not exist yet in this worktree (Fase 3 has not
// been built) — this client has never been exercised against a live server.
// See ./README.md for the feature-flag mechanism and its rationale.

const BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ?? "";

// Fase 3's documented scope also includes `POST /api/v1/registrations` and
// `POST /api/v1/sessions` (email + password login, JWT/session token). This
// app is public search only per the PRD — no auth, no logged-in state — so
// those two endpoints are intentionally NOT implemented anywhere under
// lib/api/. See ./README.md for the full rationale.

/** How long a real API call may hang before we treat the backend as
 * unreachable and surface a network error. Doubles as the "cheap
 * reachability signal" from PLAN.md Fase 4: a slow/dead backend fails fast
 * instead of hanging the request or the build. */
const REQUEST_TIMEOUT_MS = 5000;

export class ApiError extends Error {
  /** HTTP status code, when the backend answered but with a non-2xx status.
   * Absent for network-level failures (unreachable host, timeout, DNS). */
  status?: number;

  constructor(message: string, options?: { status?: number; cause?: unknown }) {
    super(message, { cause: options?.cause });
    this.name = "ApiError";
    this.status = options?.status;
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
    throw new ApiError(`API request failed: ${response.status} ${path}`, {
      status: response.status,
    });
  }

  return response.json() as Promise<T>;
}
