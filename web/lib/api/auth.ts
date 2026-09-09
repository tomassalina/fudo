// Real fetch implementations for POST /api/v1/sessions (login) and
// POST /api/v1/registrations (signup). Confirmed against the live backend
// (localhost:3000) with curl before writing any of this — not assumed from
// PLAN.md's prose. Actual transcripts (also in the task's final report):
//
//   POST /api/v1/sessions {"email":"info@tomassalina.com","password":"Demo1234"}
//   -> 200 {"consumer":{"id":"...","email":"...","first_name":"Tomas","last_name":"Salina","phone":"+5491122334455"},"token":"eyJ..."}
//
//   POST /api/v1/sessions {"email":"info@tomassalina.com","password":"wrong"}
//   -> 401 {"error":"Invalid email or password"}
//
//   POST /api/v1/registrations {"registration":{"email":"...","password":"...","first_name":"...","last_name":"...","phone":"..."}}
//   -> 201 {"consumer":{...},"token":"eyJ..."} — no dni, no password_confirmation,
//      matches RegisterForm's actual fields exactly.
//   -> 422 {"errors":{"email":["has already been taken"]}} (duplicate email)
//
// `dni` was required on this endpoint (`422 {"errors":{"dni":["can't be
// blank"]}}` with none sent) until backend commit 1cdb20e made it optional
// specifically on registration — re-confirmed live after that fix landed.
//
// Neither endpoint is behind `isApiConfigured()`/the mock-vs-real switch the
// rest of lib/api/ uses (see ./README.md): unlike merchant browsing, there
// is no mock fallback for auth — SessionProvider always calls these for
// real, because a mocked login was never a legitimate substitute for
// "is this a real account with a real password".

import { apiFetch, ApiError } from "./client";

/** Wire shape of ConsumerBlueprint (backend/app/blueprints/consumer_blueprint.rb)
 * — deliberately excludes password_hash, dni (encrypted PII) and audit
 * columns. `dni` and `created_at` are therefore NEVER present on a real
 * consumer from these two endpoints; `Consumer`'s optional `dni`/`createdAt`
 * fields (lib/session/session-provider.tsx) will stay `undefined` for every
 * real session — this is expected, not a bug, see that file's mapping
 * comment. */
export interface RawConsumer {
  id: string;
  email: string;
  first_name: string;
  last_name: string;
  phone: string | null;
}

export interface AuthResponse {
  consumer: RawConsumer;
  token: string;
}

export interface LoginInput {
  email: string;
  password: string;
}

export interface RegisterInput {
  email: string;
  password: string;
  /**
   * NOT collected by RegisterForm (single password field, no confirmation
   * UI) — omitting it entirely is safe, confirmed live:
   * `has_secure_password`'s confirmation validation only runs when this key
   * is present at all.
   */
  password_confirmation?: string;
  first_name: string;
  last_name: string;
  phone: string;
  /**
   * NOT collected by RegisterForm — per design.md Decision 1, DNI is loaded
   * by the waiter at checkout, not typed in by the consumer at signup. Was
   * required by the backend until commit 1cdb20e made it optional on this
   * endpoint specifically (confirmed live: `201` + a real JWT with no `dni`
   * in the payload) — kept optional here, not removed, so this type doesn't
   * lie about what the backend accepts.
   */
  dni?: string;
}

/** Backend error-body shapes actually observed (see the header comment) —
 * used by session-provider.tsx to pick a Spanish, user-facing message
 * instead of surfacing raw API text. */
export interface SessionErrorBody {
  error?: string;
}

export interface RegistrationErrorBody {
  errors?: Record<string, string[]>;
}

export async function login(input: LoginInput): Promise<AuthResponse> {
  return apiFetch<AuthResponse>("/sessions", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });
}

export async function register(input: RegisterInput): Promise<AuthResponse> {
  return apiFetch<AuthResponse>("/registrations", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ registration: input }),
  });
}

export { ApiError };
