"use client";

// Real interactive map (OpenStreetMap + CartoDB Dark Matter tiles, per the
// PRD) replacing the earlier decorative placeholder. Leaflet reads
// `window`/`document` when its modules are evaluated, which breaks Next's
// SSR/prerendering — so the actual map (LeafletMap.tsx) is loaded via
// next/dynamic with `ssr: false`. That option only works inside a Client
// Component (Next.js's own docs: "ssr: false is not allowed with
// next/dynamic in Server Components"), hence this thin 'use client'
// wrapper.
import dynamic from "next/dynamic";
import type { ReactNode } from "react";
import type { Merchant } from "@/lib/types";
import type { Coordinates } from "@/lib/location/use-location";
import { cn } from "@/lib/utils/cn";

const LeafletMap = dynamic(
  () => import("./LeafletMap").then((mod) => mod.LeafletMap),
  {
    ssr: false,
    loading: () => (
      <div className="flex h-full items-center justify-center text-[12px] text-foreground-muted">
        Cargando mapa…
      </div>
    ),
  },
);

export interface MapPanelProps {
  merchants: Merchant[];
  /** Type-label pill under each pin — see LeafletMap's own doc comment on `showLabels`. */
  showLabels?: boolean;
  /**
   * "panel" (default) — rounded, bordered box: the desktop split view's map
   * column. "fullscreen" — edge-to-edge, no rounding/border: the phone
   * full-screen map view (MapToggleSection), which is meant to visually
   * bleed to the screen edges rather than sit in a boxed card.
   */
  variant?: "panel" | "fullscreen";
  /** See LeafletMap's `PopupWatcher` doc comment — only wired up by the phone full-screen map view. */
  onPopupOpenChange?: (open: boolean) => void;
  /** The visitor's own live position (from `useLocation()`'s `coords`), if
   * already granted — passively consumed, never requested from here. `null`/
   * omitted just renders the map with no "you are here" marker, same as
   * today. See LeafletMap's own doc comment on why this is a dedicated prop
   * instead of a synthetic `Merchant`. */
  userLocation?: Coordinates | null;
  /** See LeafletMap's own doc comment on `onVisibleMerchantsChange` — only
   * wired up by the desktop split view's compact list. */
  onVisibleMerchantsChange?: (visible: Merchant[]) => void;
  /**
   * Floats on top of the map itself (search bar + filter trigger, in
   * practice) instead of sitting in normal document flow above it — the
   * desktop split view's own equivalent of MapToggleSection's phone
   * `overlay` prop (same reasoning: this panel, not some ancestor's normal
   * flow, is what should visually own the row that sits on top of it).
   * `undefined`/`null` renders no overlay row, same as today for every
   * existing caller.
   */
  overlay?: ReactNode;
}

export function MapPanel({
  merchants,
  showLabels = false,
  variant = "panel",
  onPopupOpenChange,
  userLocation,
  onVisibleMerchantsChange,
  overlay,
}: MapPanelProps) {
  return (
    <div
      className={cn(
        "relative h-full min-h-[280px] overflow-hidden bg-[#101119]",
        variant === "panel" && "rounded-2xl border border-border",
      )}
    >
      <LeafletMap
        merchants={merchants}
        showLabels={showLabels}
        onPopupOpenChange={onPopupOpenChange}
        userLocation={userLocation}
        onVisibleMerchantsChange={onVisibleMerchantsChange}
      />

      {overlay ? (
        // z-[1001]: same reasoning as MapToggleSection's identical overlay
        // row — above Leaflet's own panes/zoom control (cap ~700) and the
        // "Buscando en la zona…" chip (z-[1000]).
        <div className="absolute inset-x-3 top-3 z-[1001] flex flex-col gap-2.5">
          {overlay}
        </div>
      ) : null}
    </div>
  );
}
