"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import type { DishSearchResult, Merchant } from "@/lib/types";
import { MerchantCard } from "./MerchantCard";
import { DishCard } from "./DishCard";
import { CardSkeleton } from "./CardSkeleton";
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
/** Matches the design's own `loadMore` (`setTimeout(..., 750)` in
 * `docs/design-reference/Fudo App.dc.html`) — there's no real network
 * latency to wait on (the full filtered array is already in hand, see the
 * file-level comment above), but revealing the next 10 instantly would skip
 * the skeleton the design explicitly specifies for this moment
 * (`showSkels: st.refiltering || st.loadingMore`). This is that same
 * deliberate, simulated delay. */
const LOAD_MORE_DELAY_MS = 750;

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
  const [loadingMore, setLoadingMore] = useState(false);
  const sentinelRef = useRef<HTMLDivElement>(null);
  const gridRef = useRef<HTMLDivElement>(null);
  const [columns, setColumns] = useState(1);

  const canLoadMore = visibleCount < total && !loadingMore;

  /** Desktop's grid is `repeat(auto-fit, minmax(260px, 1fr))` — the real
   * column count depends on viewport width and isn't knowable from CSS
   * alone. `getComputedStyle(...).gridTemplateColumns` returns the
   * browser's post-layout resolved track list (one length per actual
   * column), so reading and counting that is the only way to know the true
   * column count without duplicating the browser's own auto-fit sizing math
   * in JS. A `ResizeObserver` on the grid keeps it correct across live
   * viewport/container resizes (not just a resize *event*, which wouldn't
   * fire for container-driven layout changes e.g. a sidebar toggling). */
  useEffect(() => {
    if (isPhone) return;
    const grid = gridRef.current;
    if (!grid) return;

    const updateColumns = () => {
      const count = getComputedStyle(grid).gridTemplateColumns.split(" ").filter(Boolean).length;
      setColumns(count > 0 ? count : 1);
    };

    updateColumns();
    const observer = new ResizeObserver(updateColumns);
    observer.observe(grid);
    return () => observer.disconnect();
  }, [isPhone]);

  useEffect(() => {
    const sentinel = sentinelRef.current;
    if (!sentinel || !canLoadMore) return;

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting) setLoadingMore(true);
      },
      { rootMargin: "400px" },
    );
    observer.observe(sentinel);
    return () => observer.disconnect();
  }, [canLoadMore]);

  useEffect(() => {
    if (!loadingMore) return;
    const timer = setTimeout(() => {
      setVisibleCount((count) => Math.min(count + PAGE_SIZE, total));
      setLoadingMore(false);
    }, LOAD_MORE_DELAY_MS);
    return () => clearTimeout(timer);
  }, [loadingMore, total]);

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

  /** Fill only the missing slots in the current (possibly partial) last row
   * — not a fixed count. Rendered as siblings of the real cards inside the
   * SAME grid container (see below) so CSS grid auto-placement continues
   * the incomplete last row before wrapping, instead of us computing row
   * boundaries manually. */
  const remainder = visibleCount % columns;
  const desktopSkeletonCount = remainder === 0 ? columns : columns - remainder;

  return (
    <div>
      <div ref={gridRef} className={containerClass}>
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

        {!isPhone && loadingMore
          ? Array.from({ length: desktopSkeletonCount }, (_, i) => <CardSkeleton key={i} />)
          : null}
      </div>

      {isPhone && loadingMore ? (
        <div aria-hidden className="flex flex-col gap-[11px] pt-[11px]">
          {[0, 1, 2].map((i) => (
            <RowSkeleton key={i} />
          ))}
        </div>
      ) : null}

      {visibleCount < total ? (
        <div ref={sentinelRef} aria-hidden className="h-1 w-full" />
      ) : null}
    </div>
  );
}

/** The `isList` loading-more skeleton row (`skeletons`/`showSkels` in
 * `docs/design-reference/Fudo App.dc.html`): same 88×88 thumbnail + 3-bar
 * text shape as a real `MerchantCard` row, with a shimmer sweep instead of
 * content — reused as-is rather than inventing a different placeholder
 * shape for the "loading the next 10" moment. */
function RowSkeleton() {
  return (
    <div className="flex gap-3 rounded-[18px] border border-border bg-surface p-2.5">
      <div className="relative h-[88px] w-[88px] flex-none overflow-hidden rounded-[13px] bg-surface-2">
        <span className="absolute inset-0 animate-fudo-shimmer bg-gradient-to-r from-transparent via-[var(--highlight)] to-transparent" />
      </div>
      <div className="flex flex-1 flex-col gap-[9px] pt-1.5">
        <span className="h-[15px] w-[65%] rounded-md bg-surface-2" />
        <span className="h-[11px] w-[45%] rounded-md bg-surface-2" />
        <span className="h-[11px] w-[30%] rounded-md bg-surface-2" />
      </div>
    </div>
  );
}
