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
| `GET /api/v1/loyalty_rules?merchant_id=X`| `lib/api/loyalty.ts` — **public, no auth** (`index`/`show` are excluded from `authenticate_consumer!`). Real per-merchant reward ladder, confirmed genuinely isolated per merchant. Facade: `lib/data/loyalty.ts` (Pattern A, mock/real switch). |
| `GET /api/v1/visits`                     | `lib/api/visits.ts` — authenticated, scoped to `current_consumer.visits`. No mock mode (Pattern B, same as favorites/gifts/consumer-settings) — see `lib/visits/use-visit-history.ts`. |
| `GET /api/v1/visit_summaries`            | `lib/api/visits.ts` — authenticated, scoped to `current_consumer.visit_summaries`; `count`/`last_visit_at` per merchant drive real `LoyaltyProgress`/Perfil visit history. Same hook as `visits` above. |

`POST /api/v1/search` is **not called** — see point 4 above. Confirmed
filter query params on `GET /api/v1/merchants` are `neighborhood`, `type`,
`tags` (CSV, e.g. `?tags=vegano,sin_tacc`), `price_per_person`, `page`, and
`per_page`. Of these, only `tags` is wired into `fetchMerchants()` (forwarded
by `lib/data/search.ts` in real-API mode) — it has to be: the list response
never echoes `tags` back, so a client-side `tags.some(...)` filter is always
false against real merchants (every one parses to `tags: []`). `type` stays
client-side — the list response always includes the real `type`, so
filtering it client-side just works, same as the mock layer always did.
`neighborhood` and `price_per_person` aren't wired in either; nothing needs
them yet (~30 rows, no real need for that server-side filtering). Documented
here for whoever wants to add them later.

## Auth (superseded — kept for history)

This section originally said `POST /api/v1/registrations` /
`POST /api/v1/sessions` were **intentionally not implemented anywhere in
this app**, per a PRD reading that this Next.js app's scope was public,
unauthenticated pages only. A later session added a real login/registro
flow anyway (`auth.ts`, `favorites.ts`, `consumer-settings.ts` in this
directory, plus `lib/session/session-provider.tsx`) — see those files'
header comments for the real, confirmed request/response shapes. Unlike
merchants/menu-items, auth and every protected endpoint are NOT behind the
`isApiConfigured()` mock/real switch described above: there is no mocked
login anymore, so these always call the real backend directly.
`POST /api/v1/search` is still not called here (see point 4 above) — that
reasoning is unaffected by auth becoming real.

## Layout

- `client.ts` — `apiFetch`, `ApiError`, `isApiConfigured`.
- `merchants.ts`, `menu-items.ts`, `loyalty.ts` — real `fetch`
  implementations for the public endpoints, returning the same shapes as
  `lib/types`. `../data/*` is the facade pages/components actually import
  from for these (picks mock vs. real per `isApiConfigured()`).
- `auth.ts` — real `POST /api/v1/sessions` / `POST /api/v1/registrations`.
- `favorites.ts`, `consumer-settings.ts`, `visits.ts` — real, authenticated
  (`Authorization: Bearer <token>`) reads/CRUD for the current consumer's own
  favorites, settings, and visit history. No `isApiConfigured()` switch —
  see "Auth (superseded)" below. `visits.ts` is consumed via a hook
  (`lib/visits/use-visit-history.ts`), not a `lib/data/*` facade — see that
  hook's header comment for why (Pattern B: authenticated-only, no mock
  mode, so there's nothing to switch between).
- `../data/*` — the facade pages actually import from for the public,
  mock-or-real resources; picks mock vs. real per `isApiConfigured()` and
  exposes one async function per screen need, regardless of which backend
  answers it.
