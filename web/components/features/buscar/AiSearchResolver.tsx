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
// (`type`/`hood`/`tags`/`price`/`open`/`reward`) this app's other filters
// already use — a shareable link, same convention as
// `?sort=distancia`/`?open=now` (see lib/utils/buscar-href.ts). On failure
// (network error, Gemini unavailable,
// mock/local mode with no real backend, or the visitor isn't logged in —
// this endpoint requires `authenticate_consumer!`, see search_controller.rb)
// it degrades to a plain name-only search with the same text instead of
// leaving the visitor stuck on a skeleton forever.

import { useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import { resolveAiSearchFilters } from "@/lib/search/resolve-ai-search";
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
  // StrictMode/dev double-invokes effects — this guards against firing the
  // (non-idempotent, billed) Gemini call twice for one submission.
  const startedRef = useRef(false);

  useEffect(() => {
    if (startedRef.current) return;
    startedRef.current = true;
    let cancelled = false;

    resolveAiSearchFilters(query)
      .then((filters) => {
        if (cancelled) return;
        router.replace(
          buscarHref(DEFAULT_BUSCAR_PARAMS, {
            type: presetType || filters.type,
            hood: filters.neighborhood,
            tags: filters.tags.length > 0 ? filters.tags.join(",") : null,
            price: filters.priceBand,
            open: filters.open,
            reward: filters.reward,
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
