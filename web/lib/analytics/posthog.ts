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

const POSTHOG_KEY = process.env.NEXT_PUBLIC_POSTHOG_KEY;
const POSTHOG_HOST = process.env.NEXT_PUBLIC_POSTHOG_HOST;

/** Both env vars must be set for analytics to do anything at all. */
export const isPostHogEnabled = Boolean(POSTHOG_KEY && POSTHOG_HOST);

let initialized = false;

/**
 * Initializes the posthog-js singleton. Safe to call multiple times (guarded
 * by `initialized`) and safe to call when analytics is disabled (no-ops).
 * Client-only — must run in a "use client" component.
 */
export function initPostHogClient() {
  if (!isPostHogEnabled || initialized) return;

  posthog.init(POSTHOG_KEY as string, {
    api_host: POSTHOG_HOST,
    // We fire $pageview manually (see PostHogPageview.tsx) — posthog-js's
    // default autocapture doesn't hook App Router client-side navigations.
    capture_pageview: false,
    // No cookie-consent UI in this app yet — keep the scaffold conservative
    // until that ships. Follow-up: PostHog's default init still sets its own
    // identification cookie/localStorage entry even with recording off; a
    // real consent banner is out of scope for this pass (see report).
    disable_session_recording: true,
  });

  initialized = true;
}

/** Fire-and-forget capture — no-ops when analytics is disabled. */
export function capture(event: string, properties?: Record<string, unknown>) {
  if (!isPostHogEnabled) return;
  posthog.capture(event, properties);
}
