// PostHog Cloud client-side analytics — see PRD ("Feature flags, A/B testing y
// analytics de producto: todo con PostHog Cloud, nunca self-hosteado") and
// ENV_SETUP.md §4 for the env var convention.
//
// This module is a safe no-op whenever NEXT_PUBLIC_POSTHOG_KEY/HOST aren't
// set — which is the real-world default today (no PostHog project exists
// yet). No key means: no posthog.init() call, no network calls, no console
// errors, local dev and CI behave exactly as before.
//
// Session recording is explicitly disabled: this is a public marketing/search
// site with no cookie-consent UI yet, so the initial scaffold stays
// conservative. See PostHogProvider.tsx for the cookie note.

import posthog from "posthog-js";
import type { CaptureResult, Properties } from "posthog-js";

const POSTHOG_KEY = process.env.NEXT_PUBLIC_POSTHOG_KEY;
const POSTHOG_HOST = process.env.NEXT_PUBLIC_POSTHOG_HOST;

/** Both env vars must be set for analytics to do anything at all. */
export const isPostHogEnabled = Boolean(POSTHOG_KEY && POSTHOG_HOST);

// posthog-js attaches URL-bearing properties to EVERY event automatically —
// $current_url + $host/$pathname on every capture, plus $referrer/
// $referring_domain, and person/session-level derivatives like
// $initial_current_url and $session_entry_url — regardless of what
// properties app code passes to capture(). This is core SDK behavior, not
// something this module controls per event: see
// node_modules/.pnpm/@posthog+browser-common@0.8.2/node_modules/@posthog/
// browser-common/dist/utils/event-utils.js (getEventProperties/
// getPersonInfo/getPersonPropsFromInfo), bundled into posthog-js.
//
// That means on /buscar?q=<literal search text>, the literal query text
// this app deliberately keeps OUT of search_performed's own properties (see
// SearchAnalytics.tsx) would otherwise ride along anyway via $current_url on
// the $pageview event — and via $referrer on whatever page a full navigation
// away from /buscar?q=... lands on next, since search here is a plain GET
// form (see app/buscar/page.tsx).
//
// `before_send` is the real, current config hook for stripping this before
// events leave the browser — see the installed posthog-js v1.428.6's own
// type package: node_modules/.pnpm/@posthog+types@1.409.2/node_modules/
// @posthog/types/src/posthog-config.ts:2083
// (`before_send?: BeforeSendFn | BeforeSendFn[]`), and its JSDoc at line
// 1335 explicitly recommends it for removing "sensitive hash values before
// events are sent" — the same pattern applies to sensitive query values.
// The older `sanitize_properties` hook is explicitly superseded by it
// (same file, line 2102: "@deprecated - use `before_send` instead").
// `before_send` runs in posthog-core.js's capture() AFTER all SDK-computed
// properties (including $current_url) are attached and right before the
// event is queued/sent, so it sees — and can rewrite — everything that
// would otherwise go out over the wire.
//
// Rather than allowlisting exact property names (which would silently miss
// any new URL-bearing property a future posthog-js version adds), a
// property is treated as URL-bearing when either its KEY looks like one
// (contains "url" or "referr", case-insensitively — covers $current_url,
// $referrer, $referring_domain, $session_entry_url, $initial_current_url,
// $initial_referrer, and anything shaped like them; "referr" rather than
// "referrer" so it also matches "referring", which "referrer" alone does
// not) OR, as a backstop for an unexpected key name, its STRING VALUE looks
// like an absolute URL.
//
// The key-based check matters: this app's own PostHogPageview.tsx passes
// `$current_url` as a root-relative "pathname?search" string (not an
// absolute URL — see its `capture("$pageview", { $current_url: url })`
// call), because posthog-js's own capture_pageview autocapture is disabled
// here and doesn't hook Next.js App Router client-side navigations. A
// value-shape-only check (e.g. requiring an "http(s)://" prefix) misses
// that relative form entirely — confirmed live: before this key-based
// check was added, `search_performed`'s SDK-computed (absolute)
// `$current_url` was correctly redacted, but the manually-built
// (relative) `$current_url` on `$pageview` still carried the literal
// `q=` text straight through.
//
// Only the query string (where free-text search params like `?q=` live)
// is stripped — path and host are left intact; closed-vocabulary params
// like `type`/`tags` go with it too, but those are already sent
// explicitly and safely via search_performed's own properties, so
// nothing is lost.
const URL_LIKE_PROPERTY_KEY = /url|referr/i;

function isUrlLikeProperty(key: string, value: unknown): value is string {
  if (typeof value !== "string") return false;
  return URL_LIKE_PROPERTY_KEY.test(key) || /^https?:\/\//i.test(value);
}

/** Truncates at the first `?`, working for both absolute and root-relative URL strings. */
function stripQueryString(url: string): string {
  const queryIndex = url.indexOf("?");
  return queryIndex === -1 ? url : url.slice(0, queryIndex);
}

function stripUrlQueryStrings(properties: Properties | undefined | null): void {
  if (!properties) return;
  for (const key of Object.keys(properties)) {
    const value = properties[key];
    if (isUrlLikeProperty(key, value)) {
      properties[key] = stripQueryString(value);
    }
  }
}

/** `before_send` hook: redacts query strings from URL-bearing properties on every event. */
function redactUrlQueryStrings(result: CaptureResult | null): CaptureResult | null {
  if (!result) return result;
  stripUrlQueryStrings(result.properties);
  stripUrlQueryStrings(result.$set);
  stripUrlQueryStrings(result.$set_once);
  return result;
}

// Initialize at MODULE SCOPE, not inside a React effect/component.
//
// posthog-js's capture() is gated by an internal `__loaded` flag that only
// flips to true once init() has run; until then capture() is a pure no-op
// (there is no pre-init queue in the npm client, unlike the <script>-tag
// snippet install). If init() instead ran inside PostHogProvider's own
// useEffect, it would lose the race on every fresh page load: React fires
// child effects before a parent's own effect on mount, so a child tracker
// mounted inside PostHogProvider (PostHogPageview/SearchAnalytics/
// MerchantViewedTracker) would call capture() from ITS effect before
// PostHogProvider's effect had called init() — silently dropping the
// first event of every session, which is the common SEO/organic-traffic
// landing case (e.g. landing directly on /restaurantes/42).
//
// Module-level code runs once, during import/evaluation, which always
// completes before React's render/effect phases start — so there is no
// ordering race here. Guarded by `typeof window` because this module is
// also evaluated on the server (Next.js still executes "use client"
// component code during SSR); posthog.init() must never run there.
if (typeof window !== "undefined" && isPostHogEnabled) {
  posthog.init(POSTHOG_KEY as string, {
    api_host: POSTHOG_HOST,
    // We fire $pageview manually (see PostHogPageview.tsx) — posthog-js's
    // default autocapture doesn't hook App Router client-side navigations.
    capture_pageview: false,
    // Every event this app cares about ($pageview, search_performed,
    // merchant_viewed) is already manually instrumented — this app has zero
    // use for PostHog's default click/form/pointer autocapture ($autocapture
    // is `true` by default). Turning it off closes an entire class of leak,
    // not just one instance: FilterChips.tsx renders <Link>s whose `href` is
    // literally `/buscar?q=<search text>&type=...`, and clicking one would
    // otherwise fire a default $autocapture click event whose
    // `properties.$elements[*].attr__href` carries that same literal query
    // string — nested inside an array, so before_send's stripUrlQueryStrings
    // above (which only walks top-level properties) would never touch it.
    // Verified against the installed posthog-js v1.428.6 source (types
    // don't show implementation, so read the actual bundled JS): in
    // node_modules/.pnpm/posthog-js@1.428.6.../node_modules/posthog-js/
    // dist/module.full.js, the autocapture class's config refresh does
    // `t.enabled = !!e.autocapture` (Kb.refresh), and its dispatcher `ho()`
    // — which handles click/submit/change/pointer events and fires BOTH
    // `$autocapture` and the rageclick variant `$rageclick` (dispatched via
    // a recursive `this.ho(t, "$rageclick", i)` call from inside the same
    // method) — starts with `if (this.isEnabled)` and returns immediately
    // otherwise. So `autocapture: false` doesn't just suppress one autocapture
    // event type while leaving others on: it disables the listener setup
    // entirely (`startIfEnabled()` never calls `lo()`, which is what
    // attaches the click/submit/change/pointer DOM listeners in the first
    // place), so neither $autocapture nor $rageclick can fire. Separately,
    // `capture_dead_clicks` and `capture_heatmaps` are independent opt-in
    // features (default `undefined`/off, per @posthog/types'
    // posthog-config.ts) that this app's config never enables, so they're
    // not a live leak vector here either.
    autocapture: false,
    // No cookie-consent UI in this app yet — keep the scaffold conservative
    // until that ships. Follow-up: PostHog's default init still sets its own
    // identification cookie/localStorage entry even with recording off; a
    // real consent banner is out of scope for this pass (see report).
    disable_session_recording: true,
    // Strip free-text search queries (and any other sensitive query-string
    // content) out of every SDK-attached URL property before events leave
    // the browser. See the comment on redactUrlQueryStrings above for why
    // this is needed and why before_send is the right hook for it.
    before_send: redactUrlQueryStrings,
  });
}

/** Fire-and-forget capture — no-ops when analytics is disabled. */
export function capture(event: string, properties?: Record<string, unknown>) {
  if (!isPostHogEnabled) return;
  posthog.capture(event, properties);
}
