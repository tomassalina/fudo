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
import type { Merchant } from "@/lib/types";
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
}

export function MapPanel({
  merchants,
  showLabels = false,
  variant = "panel",
  onPopupOpenChange,
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
      />
    </div>
  );
}
