# `lib/api/` — real backend client (Fase 4 prep)

## Live verification

The real backend was confirmed live and smoke-tested against, mid-task, in
this worktree — this is not the original "backend doesn't exist yet"
state this directory was first written under. What was actually checked,
directly (curl + a running `pnpm dev`), not assumed:

- `GET /api/v1/merchants`, `GET /api/v1/merchants/:id`,
  `GET /api/v1/merchants/:id/menu_items` (**404 — wrong path, see below**),
  `GET /api/v1/menu_items?merchant_id=X` (the real path), `POST
  /api/v1/search` (**401 — requires auth, see below**), and the live
  `/api-docs/v1/swagger.yaml` for the authoritative shape of each.
- `pnpm --dir web dev` with `NEXT_PUBLIC_API_BASE_URL=http://localhost:3000/api/v1`
  pointed at the live server: `/buscar` rendered real merchants (names,
  neighborhoods, prices matching the raw curl output byte-for-byte), the
  `?type=cafe` filter chip correctly narrowed results to the 6 real cafés,
  and `/restaurantes/1` rendered real business hours and real menu items
  after the fixes below.

This backend is still under active development in another session/worktree
(not merged to `main`) — treat all of this as a snapshot of what was true
during that verification pass, not a permanent guarantee. The
feature-flag/mock-fallback design (below) is intentionally unaffected by
any of this: it exists for exactly this situation, a real backend that may
or may not be up at any given moment.

### What was wrong in the first draft of this client, and the fix

Live testing surfaced four real mismatches between what PLAN.md's prose
described (and what this directory first guessed) and what the backend
actually does — all fixed in the code, listed here so the reasoning isn't
lost:

1. **`GET /api/v1/merchants` (list) returns a narrower merchant shape than
   `GET /api/v1/merchants/:id` (detail).** Confirmed via curl and the
   swagger spec: the list only guarantees `id, name, type, city, latitude,
   longitude` (`neighborhood, price_per_person_min/max, cover_image_url`
   are present but nullable) — no `address`, `state`, `country`,
   `whatsapp_number`, `delivery_url`, or `tags`. Those only come back from
   the detail endpoint. `parseMerchant` in `merchants.ts` now treats all
   of those as optional and defaults them (`""` for address/state, tags to
   `[]`, etc.) — real for a merchant fetched via detail, empty/default for
   one that only came from the list (i.e. every `/buscar` search result
   card). Concretely: on `/buscar`, real merchant cards render without tag
   chips and without a topDish line (neither is in the list response),
   since none of that made it into the confirmed list contract.
2. **Business hours times are full ISO 8601 timestamps, not `"HH:MM:SS"`.**
   e.g. `"opens_at": "2000-01-01T15:30:00.000Z"`, not the `"15:30:00"`
   shape `lib/types` documents and `lib/mock/business-hours.ts`'s
   `formatHm` (`time.slice(0, 5)`) assumes. This would have silently
   rendered garbage ("2000-" instead of a time) had it shipped unfixed —
   found only by rendering `/restaurantes/1` against the live server and
   looking at the actual hours list. Fixed by extracting the `HH:MM:SS`
   substring at the API boundary (`parseTimeOfDay` in `merchants.ts`) —
   read literally, not timezone-converted, consistent with PLAN.md's "no
   timezone logic anywhere in this project" decision.
3. **The real menu items route is `GET /api/v1/menu_items?merchant_id=X`,
   not `GET /api/v1/merchants/:id/menu_items`.** The nested path PLAN.md
   documents returns a 404 `RoutingError` on the live server — confirmed
   by curl. Fixed in `menu-items.ts`. Also confirmed paginated
   (`{ data, meta }`, same as merchants) and that `section` is nullable
   (defaulted to `"Otros"` since `groupMenuItemsBySection` groups by it).
4. **`POST /api/v1/search` requires a logged-in consumer
   (`security: bearer_auth`).** Confirmed by curl: `401 {"error":"Not
   authenticated"}` with no token. This app is intentionally
   public/unauthenticated (see "Out of scope: auth" below), so this
   endpoint can never be called here without contradicting that scope
   decision. **`lib/api/search.ts` was removed** — `lib/data/search.ts`
   now fetches the merchant list (mock or real, whichever
   `isApiConfigured()` picks) and filters it client-side with the same
   `lib/mock/search.ts` logic in both modes, instead of hitting the
   NLP endpoint at all. This isn't a regression versus what real
   natural-language search would have done here — this app never had real
   NLP search; see `lib/mock/search.ts`'s own header comment.

## Feature flag: hard switch, not fallback

`isApiConfigured()` (in `client.ts`) is `true` only when
`NEXT_PUBLIC_API_BASE_URL` is set. `lib/data/*` (the facade the pages
actually import from) checks it once per call and picks one of two paths:

- **Unset (the default in local dev/CI unless someone opts in):** always
  use `lib/mock/*`. No network code runs, no fetch is even attempted. This
  is why default behavior is unchanged byte-for-byte.
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
looking at (and can debug) the real thing. This still holds even now that
the backend is confirmed live — it's a moving target in another session,
so the app needs to keep working when it's down just as much as when it's
up.

The `REQUEST_TIMEOUT_MS` in `client.ts` (5s) is the "cheap reachability
signal" mentioned in PLAN.md: rather than adding a separate health-check
round trip before every page render, every real request fails fast via
`AbortSignal.timeout` instead of hanging indefinitely when the backend is
down or unreachable.

## Endpoint coverage

Implements the read-only, public-facing subset of the Fase 3 contract that
this app's screens (`/buscar`, `/restaurantes/[id]`) actually need — real
paths and shapes, confirmed live (see above), not PLAN.md's prose:

| Endpoint                                 | Used by                          |
| ----------------------------------------- | --------------------------------- |
| `GET /api/v1/merchants`                  | `lib/api/merchants.ts` (list, static params, search's candidate set) |
| `GET /api/v1/merchants/:id`              | `lib/api/merchants.ts` (detail, includes embedded `business_hours`) |
| `GET /api/v1/menu_items?merchant_id=X`   | `lib/api/menu-items.ts`           |

`POST /api/v1/search` is **not called** — see point 4 above. Confirmed
filter query params on `GET /api/v1/merchants` (`neighborhood`, `type`,
`tags` CSV, `price_per_person`, `page`, `per_page`) aren't wired into
`fetchMerchants()` either — nothing calls it with filters, since
`lib/data/search.ts` fetches the unfiltered list and filters client-side
(same as the mock layer always did, ~30 rows, no real need for server-side
filtering yet). Documented here for whoever wants to add it later.

## Out of scope: auth

`POST /api/v1/registrations` and `POST /api/v1/sessions` (email + password
login, JWT/session token) are part of the Fase 3 backend contract but are
**intentionally not implemented anywhere in this app.** Per the PRD, this
Next.js app's scope is public, unauthenticated search and merchant detail
pages only — no login, no per-user data (favorites, gifts, visit history
live in the mobile app). This also means `POST /api/v1/search` can never
be used here as-is (see point 4 above) — not an oversight either time.

## Layout

- `client.ts` — `apiFetch`, `ApiError`, `isApiConfigured`.
- `merchants.ts`, `menu-items.ts` — real `fetch` implementations per
  endpoint, returning the same shapes as `lib/types`.
- `../data/*` — the facade pages actually import from; picks mock vs. real
  per `isApiConfigured()` and exposes one async function per screen need,
  regardless of which backend answers it.
