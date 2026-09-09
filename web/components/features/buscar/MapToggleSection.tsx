"use client";

import { useEffect } from "react";
import type { Merchant } from "@/lib/types";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { useScrollDirection } from "@/lib/hooks/use-scroll-direction";
import { setMapModeActive } from "@/lib/hooks/use-map-mode";
import { cn } from "@/lib/utils/cn";
import { MapPanel } from "./MapPanel";

// The design's map is a toggle (`toggleMap` — `isMap` in
// docs/design-reference/Fudo App.dc.html, "Ver mapa"/"Ver lista" button in
// both references), not an always-visible panel. Only rendered in "Lugares"
// mode — the design's map pins are merchants, not individual dishes.
//
// `showMap`/`onToggle` are lifted to BuscarView (not local state here)
// because the desktop map view isn't just this section's own panel anymore —
// it replaces BuscarView's whole [FilterSidebar | results grid] layout with
// a [compact list | big map] split (see DesktopMapSplit.tsx), so the parent
// needs the flag too.
//
// Phone-only: renders nothing at all on wide viewports. The desktop toggle
// button lives inline in BuscarView's own count/sort row instead (next to
// SortMenu, matching the design reference's single "N lugares · Relevancia ·
// Ver mapa" row) — unlike the phone pill below, it's a plain in-flow button
// with no map-mode lock or full-screen layer of its own, so it doesn't need
// this component's phone-specific machinery.
//
// Phone gets the design's floating "Mapa" pill (`showMapBtn`/`mapBtnLabel`
// in the reference): fixed above PhoneNav, reusing the same
// `useScrollDirection` hook PhoneNav uses so both retreat/return together —
// plus a full-screen map layer (`fixed`, breaking out of the page's normal
// padding/flow entirely) once active, since the design's phone map view
// occupies the whole screen below the header, not an inline panel. While
// that layer is open, `setMapModeActive` (lib/hooks/use-map-mode.ts) locks
// PhoneNav visible even though the results list's own scroll-to-hide
// behavior stays active elsewhere — the map is meant to never hide the nav,
// per the design reference — and the body's own scroll is locked too, as a
// second, independent guarantee against the same thing (rather than relying
// solely on "panning the map doesn't happen to scroll the page").
export function MapToggleSection({
  merchants,
  showMap,
  onToggle,
}: {
  merchants: Merchant[];
  showMap: boolean;
  onToggle: (next: boolean) => void;
}) {
  const isPhone = useIsPhoneViewport();
  const { visible: navVisible } = useScrollDirection();
  const phoneMapActive = isPhone && showMap;

  useEffect(() => {
    setMapModeActive(phoneMapActive);
    if (!phoneMapActive) return;

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = previousOverflow;
    };
  }, [phoneMapActive]);

  // Unlocks the nav/body if this whole section unmounts (e.g. switching to
  // "Platos" mode) while the phone map was still open, instead of leaving
  // the lock stuck on.
  useEffect(() => {
    return () => setMapModeActive(false);
  }, []);

  if (!isPhone) return null;

  return (
    <>
      <button
        type="button"
        onClick={() => onToggle(!showMap)}
        aria-pressed={showMap}
        className={cn(
          "fixed inset-x-0 z-30 mx-auto flex w-fit items-center gap-2 rounded-full border border-border bg-nav pl-[15px] pr-[18px] py-[11px] text-[14px] font-semibold text-foreground shadow-nav backdrop-blur-md transition-[transform,opacity] duration-300",
          "bottom-24",
          navVisible ? "translate-y-0 opacity-100" : "translate-y-[150%] opacity-0",
        )}
      >
        <span aria-hidden className="material-symbols text-[19px]">
          {showMap ? "format_list_bulleted" : "map"}
        </span>
        {showMap ? "Lista" : "Mapa"}
      </button>

      {showMap ? (
        <div className="fixed inset-x-0 top-20 bottom-0 z-20">
          <MapPanel merchants={merchants} showLabels variant="fullscreen" />
        </div>
      ) : null}
    </>
  );
}
