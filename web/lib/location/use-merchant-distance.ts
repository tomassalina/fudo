"use client";

// Real per-merchant distance for the Inicio/Buscar/Detalle cards — replaces
// the hardcoded "0 km" (lib/api/merchants.ts's `parseMerchant` always
// defaults `distanceKm: 0`, since a request-time API layer has no access to
// the browser's live position; see docs/visual-qa-report.md, "1. Inicio",
// hallazgo #3).
//
// Returns `null` until the visitor activates location via the header's
// "Activar ubicación" pill — callers should keep falling back to
// `merchant.distanceKm` in that case (still "0 km" for real API data, a
// known/expected gap, not a fake positive number) rather than inventing a
// distance with no real position behind it.

import { useLocation } from "./use-location";
import { haversineDistanceKm, type Coordinates } from "@/lib/utils/distance";

/** Rounded to 1 decimal, same precision `lib/mock/merchants.ts` already uses
 * for its own simulated-location distance. */
function roundToOneDecimal(value: number): number {
  return Math.round(value * 10) / 10;
}

export function useMerchantDistanceKm(merchant: Coordinates): number | null {
  const { coords } = useLocation();

  if (
    !coords ||
    !Number.isFinite(merchant.latitude) ||
    !Number.isFinite(merchant.longitude)
  ) {
    return null;
  }

  return roundToOneDecimal(haversineDistanceKm(coords, merchant));
}
