"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import type { DishSearchResult, Merchant } from "@/lib/types";
import { MerchantCard } from "./MerchantCard";
import { DishCard } from "./DishCard";
import type { ResultMode } from "./ResultModeToggle";

/** Matches the design's `page * 10` batching (`loadMore`/`page` in both
 * references) — see the file-level comment below for why this reveals from
 * an already-fetched array instead of issuing new network requests. */
const PAGE_SIZE = 10;

interface SearchResultsGridProps {
  mode: ResultMode;
  merchants: Merchant[];
  dishes: DishSearchResult[];
  emptyTitle: string;
  clearHref: string;
}

/**
 * Results list/grid with the design's infinite-scroll reveal (`loadMore`,
 * `page`, `showSkels` in `docs/design-reference/Fudo App.dc.html`) — adapted
 * to this app's architecture: the server component above already fetches
 * the *entire* filtered result set for the request (~30 merchants tops, see
 * lib/data/search.ts), so "loading more" here means revealing more of that
 * already-fetched array in view, not firing new network calls or faking a
 * cursor-pagination API param this backend doesn't confirm (see
 * lib/api/README.md). The IntersectionObserver sentinel below is the real
 * scroll-triggered reveal the design specifies; there's no server latency
 * left to mask with a skeleton once the array is already in hand — that
 * loading state is instead covered by `app/buscar/loading.tsx` (Next's own
 * `loading.js` convention), which *does* have real network latency to mask
 * once a live backend is configured.
 *
 * A new search/filter navigation must reset the reveal window instead of
 * carrying over a stale count — done via React's documented "adjust state
 * with a `key`" pattern (react.dev/learn/you-might-not-need-an-effect)
 * instead of a `useEffect` that calls `setState`: BuscarView keys this
 * component by the current filter params, so React remounts it (fresh
 * `useState` initial value) on every filter change rather than patching
 * state after the fact.
 */
export function SearchResultsGrid({
  mode,
  merchants,
  dishes,
  emptyTitle,
  clearHref,
}: SearchResultsGridProps) {
  const isPhone = useIsPhoneViewport();
  const total = mode === "platos" ? dishes.length : merchants.length;
  const [visibleCount, setVisibleCount] = useState(Math.min(PAGE_SIZE, total));
  const sentinelRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const sentinel = sentinelRef.current;
    if (!sentinel) return;

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting) {
          setVisibleCount((count) => Math.min(count + PAGE_SIZE, total));
        }
      },
      { rootMargin: "400px" },
    );
    observer.observe(sentinel);
    return () => observer.disconnect();
  }, [total]);

  if (total === 0) {
    return (
      <div className="flex flex-col items-center gap-3 rounded-2xl border border-border bg-surface px-6 py-14 text-center">
        <span aria-hidden className="material-symbols text-[30px] text-foreground-faint">
          search_off
        </span>
        <p className="max-w-[260px] font-heading text-lg font-bold text-foreground">
          {emptyTitle}
        </p>
        <Link
          href={clearHref}
          className="rounded-full bg-accent-soft px-4 py-2 text-[13px] font-semibold text-accent-light"
        >
          Ver todos los lugares
        </Link>
      </div>
    );
  }

  const layout = isPhone ? "row" : "card";
  const containerClass = isPhone
    ? "flex flex-col gap-[11px]"
    : "grid grid-cols-[repeat(auto-fit,minmax(260px,1fr))] gap-[18px]";

  return (
    <div>
      <div className={containerClass}>
        {mode === "platos"
          ? dishes
              .slice(0, visibleCount)
              .map((result) => (
                <DishCard key={result.item.id} result={result} layout={layout} />
              ))
          : merchants
              .slice(0, visibleCount)
              .map((merchant) => (
                <MerchantCard key={merchant.id} merchant={merchant} layout={layout} />
              ))}
      </div>
      {visibleCount < total ? (
        <div ref={sentinelRef} aria-hidden className="h-1 w-full" />
      ) : null}
    </div>
  );
}
