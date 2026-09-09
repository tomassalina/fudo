"use client";

// Persists the JWT issued by `POST /api/v1/sessions` or
// `POST /api/v1/registrations` (see lib/api/auth.ts) across reloads, and
// exposes it as an `Authorization` header for every protected request
// (favorites, consumer settings, ...).
//
// SECURITY TRADEOFF — deliberate, documented here so it's a visible
// decision, not a silent shortcut:
//
// This stores the raw JWT in `localStorage`, which any JavaScript running on
// this origin can read. A successful XSS attack anywhere on this app can
// steal the token and impersonate the consumer until it expires (the
// backend issues long-lived stateless JWTs with no server-side revocation —
// see the comment in session-provider.tsx's `logout`). The alternative, an
// httpOnly cookie set by the backend, is immune to that specific attack
// (page JS can't read it at all) — but it requires the backend to issue and
// read the session via `Set-Cookie`/cookie headers instead of a JSON body
// field, which is not what `sessions_controller.rb` /
// `registrations_controller.rb` do today (they return `{ token }` in the
// response body), and this app has no server-side rendering of
// consumer-specific data yet for a cookie to even be read by (every
// session-aware page is a client component, see session-provider.tsx).
// Given the backend contract and this app's current architecture,
// `localStorage` is the pragmatic choice for this stage — it works with
// what actually exists, at the cost of the XSS exposure above. Revisit this
// if/when the backend adds cookie-based auth and this app starts doing real
// SSR of authenticated data.
const TOKEN_STORAGE_KEY = "fudo:consumer-token";

export function getStoredToken(): string | null {
  try {
    return window.localStorage.getItem(TOKEN_STORAGE_KEY);
  } catch {
    // Corrupted or blocked storage (private mode, quota) — treat as "no
    // token" instead of throwing.
    return null;
  }
}

export function setStoredToken(token: string): void {
  try {
    window.localStorage.setItem(TOKEN_STORAGE_KEY, token);
  } catch {
    // Storage blocked/full — the session still works in-memory for this
    // tab, it just won't survive a reload.
  }
}

export function clearStoredToken(): void {
  try {
    window.localStorage.removeItem(TOKEN_STORAGE_KEY);
  } catch {
    // Best-effort clear — nothing else to do if this throws.
  }
}

/**
 * `Authorization` header for a protected request, or `{}` when there's no
 * token. Spread this into a `fetch`/`apiFetch` `headers` object so call
 * sites don't need an `if` for the logged-out case:
 * `headers: { ...authHeader(), "Content-Type": "application/json" }`.
 */
export function authHeader(): Record<string, string> {
  const token = getStoredToken();
  return token ? { Authorization: `Bearer ${token}` } : {};
}
