"use client";

// Real "abierto ahora" status for the merchant detail page's hours pill
// (docs/visual-qa-report.md, section 3, hallazgo #1 — the design has this
// pill between the address and the price/distance row, this implementation
// didn't have it at all). All the actual open/closed math lives in the pure,
// fully-testable `getOpenStatus` (lib/mock/business-hours.ts, re-used as-is
// for both mock and real data — see lib/data/business-hours.ts) — this hook
// only supplies "now" from the browser and re-checks it periodically.
//
// Returns `null` until the first effect flush instead of computing this
// during the server render: `/restaurantes/[id]` is statically generated at
// *build* time (see app/restaurantes/[id]/page.tsx's generateStaticParams),
// so a server-side "now" would be frozen at build time and often plain
// wrong by the time a visitor actually loads the page — same reasoning
// `lib/location/use-merchant-distance.ts` already applies to real distance
// (also `null` until the browser supplies real data). Unlike distance,
// there's no meaningful static fallback for open/closed, so callers should
// simply not render the pill while this is `null` — a very short-lived
// state that resolves on the first effect flush after mount.

import { useEffect, useState } from "react";
import { getOpenStatus, type OpenStatus } from "@/lib/mock/business-hours";
import type { DayHours } from "@/lib/mock/business-hours";

/** Re-check every minute so the pill flips to "Cerrado"/"Abierto ahora" on
 * its own for a visitor who leaves the tab open across an opening/closing
 * boundary, without needing a full page reload. */
const REFRESH_INTERVAL_MS = 60_000;

export function useOpenStatus(weekHours: DayHours[]): OpenStatus | null {
  const [status, setStatus] = useState<OpenStatus | null>(null);

  useEffect(() => {
    const update = () => setStatus(getOpenStatus(weekHours));
    update();
    const id = setInterval(update, REFRESH_INTERVAL_MS);
    return () => clearInterval(id);
  }, [weekHours]);

  return status;
}
