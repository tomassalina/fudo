"use client";

import { useState, type ReactNode } from "react";
import type { Merchant } from "@/lib/types";
import type { Coordinates } from "@/lib/location/use-location";
import { MapPanel } from "./MapPanel";
import { MerchantCard } from "./MerchantCard";

export interface DesktopMapSplitProps {
  merchants: Merchant[];
  countLabel: string;
  onExit: () => void;
  /** The visitor's own live position, if already granted — threaded straight
   * through to `MapPanel`/`LeafletMap`. `LeafletMap` is the one shared map
   * implementation for both the phone full-screen view and this desktop
   * split (see MapToggleSection's doc comment), so the "you are here" marker
   * applies here too. See `LeafletMap`'s own doc comment for why this is a
   * dedicated prop rather than a synthetic `Merchant`. */
  userLocation?: Coordinates | null;
  /**
   * Search bar + filter-trigger button, floated on top of the map column —
   * see MapPanel's own `overlay` doc comment for the top-alignment contract
   * (must line up with this component's own left-column header row below).
   * Threaded straight through to `MapPanel`'s `overlay` prop rather than
   * laid out here, since DesktopMapSplit shouldn't need to know it's
   * specifically a search bar.
   */
  mapOverlay?: ReactNode;
}

/**
 * The desktop "map view" (`showMap` on wide viewports) — per the design
 * reference this isn't the usual [FilterSidebar | results grid] two-column
 * layout with a map panel dropped in; it *replaces* that layout entirely
 * with a narrow compact-card list + a large, always-visible map while
 * active, filters hidden. BuscarView swaps this in for its whole
 * `[FilterSidebar, content column]` pair rather than nesting it inside them
 * (see that file) — self-contained here on purpose, reusing only
 * MerchantCard's existing "row" layout for the compact list entries, so it
 * can't collide with whoever owns FilterSidebar.tsx/SearchResultsGrid.tsx's
 * own internals.
 */
export function DesktopMapSplit({
  merchants,
  countLabel,
  onExit,
  userLocation,
  mapOverlay,
}: DesktopMapSplitProps) {
  // Mirrors, one level up, the narrowed-to-viewport set LeafletMap already
  // computes for its own pins (see its `onVisibleMerchantsChange` doc
  // comment) — the left column shows exactly what's currently pinned on the
  // map, Airbnb-style, instead of the full unfiltered result set. Seeded
  // with the full `merchants` list for the same reason LeafletMap seeds its
  // own pin state that way: something to show before the map's first real
  // bounds are known. Left column will resync to a fresh `merchants` (a new
  // filter/search upstream) inside the effect-driven pass LeafletMap's own
  // ZoneWatcher runs immediately on that same prop change — see its doc
  // comment.
  const [visibleMerchants, setVisibleMerchants] = useState(merchants);

  return (
    // `h-full` (not a hardcoded `calc(100vh-...)`) — this now depends on
    // BuscarView actually giving its ancestor chain a real height via
    // flexbox (`flex-1 min-h-0` on the wrappers above, only while this view
    // is showing — see BuscarView's own comment on that) instead of
    // guessing the page's total chrome (header + main's own top/bottom
    // padding + this new search-bar row) as one brittle magic number. That
    // number silently went stale the moment the search bar row above this
    // component was added/removed a few times in the same session — a real
    // height chain can't go stale the same way.
    <div className="grid h-full min-h-[520px] grid-cols-[minmax(280px,340px)_minmax(0,1fr)] items-stretch gap-4">
      <div className="flex min-h-0 flex-col gap-3">
        <div className="flex items-center justify-between px-0.5">
          <span className="text-[13px] text-foreground-muted">{countLabel}</span>
          <button
            type="button"
            onClick={onExit}
            aria-pressed
            className="flex w-fit items-center gap-1.5 rounded-full border border-border bg-surface px-4 py-2.5 text-[13px] font-semibold text-foreground transition-colors hover:border-accent/50"
          >
            <span aria-hidden className="material-symbols text-[17px]">
              format_list_bulleted
            </span>
            Ver lista
          </button>
        </div>

        {visibleMerchants.length > 0 ? (
          <div className="flex min-h-0 flex-1 flex-col gap-2.5 overflow-y-auto pr-1">
            {visibleMerchants.map((merchant) => (
              <MerchantCard key={merchant.id} merchant={merchant} layout="row" />
            ))}
          </div>
        ) : (
          <div className="flex flex-1 items-center justify-center rounded-2xl border border-border bg-surface px-4 text-center text-[13px] text-foreground-muted">
            Ningún lugar para mostrar en el mapa.
          </div>
        )}
      </div>

      <MapPanel
        merchants={merchants}
        userLocation={userLocation}
        onVisibleMerchantsChange={setVisibleMerchants}
        overlay={mapOverlay}
      />
    </div>
  );
}
