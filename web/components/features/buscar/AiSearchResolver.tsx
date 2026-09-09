"use client";

// Renders while the home hero's AI search prompt (`?ai=<free text>`, see
// HeroSearch.tsx's handleSubmit) is being resolved into real filters by the
// backend's Gemini-backed parser (POST /api/v1/search, see
// backend/app/services/search_query_parser.rb) — mounted by
// app/buscar/page.tsx INSTEAD of the normal SSR results view whenever that
// param is present, per the rule that the AI search's result is a set of
// FILTERS applied on /buscar, never a free-text name search (see
// lib/mock/search.ts's header comment for the other half of that
// separation: the plain SearchBar `q` filter is name-only and never touches
// this endpoint).
//
// Shows the exact same skeleton as the route's own Suspense fallback
// (BuscarSkeleton, shared with app/buscar/loading.tsx) the instant the
// visitor submits — Home never blocks waiting for Gemini itself, the
// navigation to /buscar happens first (see HeroSearch.tsx's handleSubmit)
// and this is what's on screen the moment it lands.
//
// Once resolved, replaces the URL with the plain filter params
// (`type`/`hood`/`tags`/`price`/`open`/`reward`, plus `q`/`mode` when Gemini
// named a specific dish/merchant — see resolve-ai-search.ts's `q`/`mode`
// doc comments) this app's other filters already use — a shareable link,
// same convention as `?sort=distancia`/`?open=now` (see
// lib/utils/buscar-href.ts). On ANY
// failure — network error, Gemini itself erroring/timing out (bounded by
// apiFetch's own REQUEST_TIMEOUT_MS, see lib/api/client.ts, so this never
// hangs waiting on the network past ~5s), or mock/local mode with no real
// backend — it degrades to a plain name-only search with the same text
// instead of leaving the visitor stuck on a skeleton. There is no separate
// dedicated "AI search failed" error screen: a plain-text /buscar result for
// the same query is itself a complete, useful result, not a dead end (and
// there is no such error-state pattern in the design reference either).
//
// GOTCHA (found live while fixing a real "stuck on skeleton forever"
// report, see openspec learnings for the full incident): StrictMode/dev
// double-invokes this effect (mount -> synchronous cleanup -> mount again).
// `startedRef` below is correct to guard the actual `resolveAiSearchFilters`
// call itself (it's a non-idempotent, billed Gemini call and must fire
// exactly once), but it must NOT also gate attaching the `.then`/`.catch`
// handlers — an earlier version returned early on the bailed-out second
// effect run before those were attached, so the surviving effect instance
// never registered a live (non-cancelled) handler at all: the FIRST effect
// run's cleanup fires immediately (StrictMode's synthetic unmount) and sets
// ITS `cancelled` closure to true; the fetch it kicked off resolves later
// against that same now-`cancelled` closure and silently no-ops instead of
// navigating. Net effect: the real network call visibly succeeds (200 in
// the Network tab) but the page never leaves the skeleton. The fix is to
// cache the in-flight promise itself in a ref (so the API call still only
// fires once) while still letting EVERY effect invocation — including the
// one that survives StrictMode's double-invoke — attach its own `cancelled`
// handlers to that shared promise.

import { useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import {
  resolveAiSearchFilters,
  type ResolvedAiFilters,
} from "@/lib/search/resolve-ai-search";
import { buscarHref, DEFAULT_BUSCAR_PARAMS } from "@/lib/utils/buscar-href";
import { BuscarSkeleton } from "./BuscarSkeleton";

export function AiSearchResolver({
  query,
  presetType,
}: {
  /** The raw natural-language text typed into the home hero. */
  query: string;
  /** The type chip explicitly selected on the home hero, if any (a real
   * `MerchantType` value, or "" for none). An explicit visitor choice always
   * wins over whatever type Gemini itself infers from the free text — see
   * the `type: presetType || filters.type` merge below. */
  presetType: string;
}) {
  const router = useRouter();
  // Guards the actual (non-idempotent, billed) Gemini call so it only fires
  // once despite StrictMode/dev's double-invoke — see the gotcha above for
  // why this must be separate from the per-effect-instance `cancelled` flag
  // below, and must not gate attaching `.then`/`.catch` at all.
  const startedRef = useRef(false);
  const resultPromiseRef = useRef<Promise<ResolvedAiFilters> | null>(null);

  useEffect(() => {
    let cancelled = false;

    if (!startedRef.current) {
      startedRef.current = true;
      resultPromiseRef.current = resolveAiSearchFilters(query);
    }

    resultPromiseRef.current!
      .then((filters) => {
        if (cancelled) return;
        router.replace(
          buscarHref(DEFAULT_BUSCAR_PARAMS, {
            q: filters.q,
            type: presetType || filters.type,
            hood: filters.neighborhood,
            tags: filters.tags.length > 0 ? filters.tags.join(",") : null,
            price: filters.priceBand,
            open: filters.open,
            reward: filters.reward,
            mode: filters.mode,
          }),
        );
      })
      .catch(() => {
        if (cancelled) return;
        router.replace(
          buscarHref(DEFAULT_BUSCAR_PARAMS, {
            q: query,
            type: presetType || null,
          }),
        );
      });

    return () => {
      cancelled = true;
    };
  }, [query, presetType, router]);

  return <BuscarSkeleton />;
}
