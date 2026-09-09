"use client";

import { useState } from "react";
import type { Merchant } from "@/lib/types";
import { MapPanel } from "./MapPanel";

// The design's map is a toggle (`toggleMap` — `isMap` in
// docs/design-reference/Fudo App.dc.html, "Ver mapa"/"Ver lista" button in
// both references), not an always-visible panel: results and map are two
// views of the same list, swapped by one button, on both phone and wide.
// Only rendered in "Lugares" mode — the design's map pins are merchants, not
// individual dishes.
export function MapToggleSection({ merchants }: { merchants: Merchant[] }) {
  const [showMap, setShowMap] = useState(false);

  return (
    <div className="flex flex-col gap-3">
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

      {showMap ? (
        <div className="h-[360px] w-full">
          <MapPanel merchants={merchants} />
        </div>
      ) : null}
    </div>
  );
}
