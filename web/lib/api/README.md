# `lib/api/` — real backend client (Fase 4 prep)

Status as of this writing: **the real backend does not exist yet.**
`backend/config/routes.rb` only has the default Rails health check and
`backend/app/controllers/` only has `application_controller.rb` — Fase 3
(`/api/v1/*`) has not been built in this worktree. Nothing in this directory
has been exercised against a live server. It exists so the swap is
mechanical once Fase 3 lands, per PLAN.md's Fase 4 scope ("se reemplaza la
capa local de fixtures por la implementación real ... sin tocar la interfaz
que ya consumen las pantallas").

## Feature flag: hard switch, not fallback

`isApiConfigured()` (in `client.ts`) is `true` only when
`NEXT_PUBLIC_API_BASE_URL` is set. `lib/data/*` (the facade the pages
actually import from) checks it once per call and picks one of two paths:

- **Unset (today's real state, and the default in local dev/CI until Fase 3
  ships):** always use `lib/mock/*`. No network code runs, no fetch is even
  attempted. This is why default behavior is unchanged byte-for-byte.
- **Set:** always use the real `fetch` implementation in this directory. No
  fallback to mock on failure — a failed request throws an `ApiError` and
  propagates to the nearest `error.tsx` boundary.

This was a deliberate choice over "try real, silently fall back to mock on
failure": once someone opts in by setting the env var (a developer testing
against a locally running backend, or a real deployment), silently serving
stale mock data on a failed request would be actively misleading — it hides
outages instead of surfacing them, and it means the loading/error UI built
for this phase would never actually be exercised. A hard switch keeps the
two data sources honest: either you're looking at fixtures, or you're
looking at (and can debug) the real thing.

The `REQUEST_TIMEOUT_MS` in `client.ts` (5s) is the "cheap reachability
signal" mentioned in PLAN.md: rather than adding a separate health-check
round trip before every page render, every real request fails fast via
`AbortSignal.timeout` instead of hanging indefinitely when the backend is
down or unreachable.

## Endpoint coverage

Implements the read-only, public-facing subset of the Fase 3 contract that
this app's screens (`/buscar`, `/restaurantes/[id]`) actually need:

| Endpoint (PLAN.md Fase 3)               | Used by                          |
| ---------------------------------------- | --------------------------------- |
| `GET /api/v1/merchants`                  | `lib/api/merchants.ts` (list, static params) |
| `GET /api/v1/merchants/:id`              | `lib/api/merchants.ts` (detail)   |
| `GET /api/v1/merchants/:id/menu_items`   | `lib/api/menu-items.ts`           |
| `POST /api/v1/search`                    | `lib/api/search.ts`               |

**Assumption, not a confirmed contract** (Fase 3 doesn't document a
dedicated business-hours endpoint): `GET /api/v1/merchants/:id` is assumed
to return `business_hours` embedded on the merchant payload, since hours
are 1:1 with a merchant and a separate endpoint isn't listed. Confirm this
against the real OpenAPI spec once Fase 3 ships and adjust
`lib/api/merchants.ts` if it's wrong (e.g. splitting into its own endpoint
or a different field name).

**Assumption on `POST /api/v1/search`**: Fase 3 describes it as free-text
only (`{ query: "..." }`, parsed server-side via Gemini). This app's
`/buscar` page also has type/tag filter chips that today filter client-side
over the full mock dataset. Since the real endpoint's exact request shape
isn't documented beyond `query`, `lib/api/search.ts` sends `{ query, type,
tags }` as a best-effort superset — the extra fields are a guess at how
structured filters might layer on top of the free-text search, not a
confirmed part of the Fase 3 contract. Revisit once the real endpoint and
its OpenAPI spec exist.

## Out of scope: auth

`POST /api/v1/registrations` and `POST /api/v1/sessions` (email + password
login, JWT/session token) are part of the Fase 3 backend contract but are
**intentionally not implemented anywhere in this app.** Per the PRD, this
Next.js app's scope is public, unauthenticated search and merchant detail
pages only — no login, no per-user data (favorites, gifts, visit history
live in the mobile app). If a future session finds no `lib/api/auth.ts`,
that's not an oversight.

## Layout

- `client.ts` — `apiFetch`, `ApiError`, `isApiConfigured`.
- `merchants.ts`, `menu-items.ts`, `search.ts` — real `fetch` implementations
  per endpoint, returning the same shapes as `lib/types`.
- `../data/*` — the facade pages actually import from; picks mock vs. real
  per `isApiConfigured()` and exposes one async function per screen need,
  regardless of which backend answers it.
