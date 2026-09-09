"use client";

import { useEffect, useState, type ReactNode } from "react";
import type { Merchant } from "@/lib/types";
import type { Coordinates } from "@/lib/location/use-location";
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
// plus a full-screen map layer (`fixed inset-0`, breaking out of the page's
// normal padding/flow entirely — true edge-to-edge, not offset below a
// header row, per the design reference: docs/design-reference/Fudo App.dc.html's
// `isMap` view has no top offset, the map fills the viewport and the search
// bar floats directly on top of it) once active, since the design's phone
// map view occupies the whole screen, not an inline panel below some other
// content. `overlay` (below) is that floating search-bar/list-toggle row —
// owned by BuscarView (it composes SearchBar/ResultModeToggle/AiChips, none
// of which this component otherwise knows about) but rendered *inside* this
// fixed layer, on top of the map, instead of in BuscarView's own normal
// document flow, which is exactly what this component replaces while the
// map is open (see BuscarView's `hidePhoneListWhileMapping`/`mapOverlay`).
// While
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
  overlay,
  userLocation,
}: {
  merchants: Merchant[];
  showMap: boolean;
  onToggle: (next: boolean) => void;
  /** Floating search-bar/toggle row rendered on top of the map — see the
   * file doc comment above. `undefined`/`null` renders no overlay row. */
  overlay?: ReactNode;
  /** Threaded straight through to `MapPanel`/`LeafletMap` — see their own
   * doc comments on the "you are here" marker. */
  userLocation?: Coordinates | null;
}) {
  const isPhone = useIsPhoneViewport();
  const { visible: navVisible } = useScrollDirection();
  const phoneMapActive = isPhone && showMap;
  // Whether a pin's MerchantMapCard popup is currently open — see
  // LeafletMap's `PopupWatcher` doc comment for why this has to live here
  // (raising the fixed map layer's own z-index) rather than something inside
  // Leaflet's DOM: the layer below is `position: fixed` with an explicit
  // `z-*` class, so it's its own stacking context, and nothing inside it can
  // ever out-rank a sibling outside it (PhoneNav, z-30) no matter what
  // z-index Leaflet gives the popup pane internally.
  const [pinCardOpen, setPinCardOpen] = useState(false);

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
        onClick={() => {
          // Stale-state guard, done here (not an effect — setState directly
          // inside an effect body is a lint error, see
          // react-hooks/set-state-in-effect): closing the map shouldn't carry
          // a "card was open" flag into the next time it's opened, which
          // would render the layer z-elevated from the start.
          if (showMap) setPinCardOpen(false);
          onToggle(!showMap);
        }}
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
        <div
          className={cn(
            // True full-viewport overlay (`inset-0`, not `top-20 bottom-0`)
            // — the map fills edge-to-edge behind the floating `overlay` row
            // below, matching the design reference instead of leaving a
            // fixed 80px gap where an (unrendered, on phone) header used to
            // reserve space. See the file doc comment above.
            "fixed inset-0",
            // z-20 normally (under PhoneNav's z-30, matching every other
            // floating pill on this screen). While a pin's card is open, the
            // whole layer rises to z-[100] — comfortably above PhoneNav
            // (z-30), the "Mapa/Lista" toggle above (also z-30), and every
            // other z-index used anywhere else in this app (the next-highest
            // is Sheet.tsx's z-50) — so the card is never clipped by any of
            // them. See the `pinCardOpen` doc comment above for why this
            // can't be scoped to just the card.
            pinCardOpen ? "z-[100]" : "z-20",
          )}
        >
          <MapPanel
            merchants={merchants}
            showLabels
            variant="fullscreen"
            onPopupOpenChange={setPinCardOpen}
            userLocation={userLocation}
          />

          {overlay ? (
            // Positioned inside this same fixed layer (not a sibling in
            // BuscarView's normal flow) so it paints on top of the map
            // regardless of DOM order — a `position: fixed` element and an
            // in-flow (`position: static`) one are compared in the
            // *positioned-elements* stacking pass, where the fixed one
            // always wins regardless of source order; this is in fact the
            // exact bug the old `top-20` layout had in reverse (confirmed
            // live during this task's Mechanism B probe: the fixed map
            // layer painted OVER the in-flow AiChips row above it, eating
            // its clicks). z-[1001]: above Leaflet's own panes/zoom control
            // (cap ~700) and the "Buscando en la zona…" chip (z-[1000]).
            <div className="absolute inset-x-0 top-[10px] z-[1001] flex flex-col gap-2.5 px-[18px]">
              {overlay}
            </div>
          ) : null}
        </div>
      ) : null}
    </>
  );
}
