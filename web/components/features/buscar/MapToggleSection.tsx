"use client";

import { useState } from "react";
import type { Merchant } from "@/lib/types";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { useScrollDirection } from "@/lib/hooks/use-scroll-direction";
import { cn } from "@/lib/utils/cn";
import { MapPanel } from "./MapPanel";

// The design's map is a toggle (`toggleMap` — `isMap` in
// docs/design-reference/Fudo App.dc.html, "Ver mapa"/"Ver lista" button in
// both references), not an always-visible panel: results and map are two
// views of the same list, swapped by one button, on both phone and wide.
// Only rendered in "Lugares" mode — the design's map pins are merchants, not
// individual dishes.
//
// Phone gets the design's floating "Mapa" pill (`showMapBtn`/`mapBtnLabel`
// in the reference): fixed above PhoneNav, and reusing the same
// `useScrollDirection` hook PhoneNav uses (see that hook's own doc comment —
// it's explicitly meant to be shared by any floating chrome that should get
// out of the way on scroll-down) so both retreat/return together instead of
// drifting out of sync with two independent scroll listeners. Wide keeps the
// original in-flow "Ver mapa" button — no bottom nav to clear there
// (WideNav is a sticky top bar), so nothing to float above.
export function MapToggleSection({ merchants }: { merchants: Merchant[] }) {
  const [showMap, setShowMap] = useState(false);
  const isPhone = useIsPhoneViewport();
  const { visible: navVisible } = useScrollDirection();

  return (
    <div className="flex flex-col gap-3">
      {isPhone ? (
        <button
          type="button"
          onClick={() => setShowMap((current) => !current)}
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
      ) : (
        <button
          type="button"
          onClick={() => setShowMap((current) => !current)}
          aria-pressed={showMap}
          className="flex w-fit items-center gap-1.5 self-end rounded-full border border-border bg-surface px-4 py-2.5 text-[13px] font-semibold text-foreground transition-colors hover:border-accent/50"
        >
          <span aria-hidden className="material-symbols text-[17px]">
            {showMap ? "format_list_bulleted" : "map"}
          </span>
          {showMap ? "Ver lista" : "Ver mapa"}
        </button>
      )}

      {showMap ? (
        <div className="h-[360px] w-full">
          <MapPanel merchants={merchants} />
        </div>
      ) : null}
    </div>
  );
}
