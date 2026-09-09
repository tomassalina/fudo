// Shared great-circle distance helper — extracted from lib/mock/merchants.ts
// (it used to define its own private copy) so the real geolocation flow
// (lib/location/use-merchant-distance.ts) can compute a merchant's distance
// from the browser's live position with the exact same formula the mock
// fixture data already used for its simulated USER_LOCATION, instead of a
// second hand-rolled implementation.

const EARTH_RADIUS_KM = 6371;

function toRadians(degrees: number): number {
  return (degrees * Math.PI) / 180;
}

export interface Coordinates {
  latitude: number;
  longitude: number;
}

/** Great-circle (haversine) distance between two lat/lng points, in kilometers. */
export function haversineDistanceKm(from: Coordinates, to: Coordinates): number {
  const dLat = toRadians(to.latitude - from.latitude);
  const dLon = toRadians(to.longitude - from.longitude);
  const lat1 = toRadians(from.latitude);
  const lat2 = toRadians(to.latitude);

  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return EARTH_RADIUS_KM * c;
}

/** Rounded to 1 decimal — the precision both the client card recalculation
 * (lib/location/use-merchant-distance.ts) and the /buscar Server Component's
 * lat/lng-driven sort/filter (app/buscar/page.tsx) use, so a merchant's
 * distance reads the same whether it was computed server-side from the
 * `?lat=&lng=` query params or client-side from the live browser position. */
export function roundToOneDecimal(value: number): number {
  return Math.round(value * 10) / 10;
}

/**
 * Formats a distance in km for display the way both design references do:
 * under 1 km shows whole meters ("800 m"), 1 km and over shows one decimal
 * with the Argentine comma separator ("2,1 km") — matches
 * `docs/design-reference/Fudo App.dc.html`'s `p.d < 1 ? Math.round(p.d *
 * 1000) + " m" : String(p.d).replace(".", ",") + " km"`. `Infinity` (the
 * "unknown distance" sentinel — see app/buscar/page.tsx's `withDistances`)
 * renders as an em dash instead of a nonsensical number.
 */
export function formatDistanceLabel(km: number): string {
  if (!Number.isFinite(km)) return "—";
  if (km < 1) return `${Math.round(km * 1000)} m`;
  return `${km.toLocaleString("es-AR", {
    minimumFractionDigits: 1,
    maximumFractionDigits: 1,
  })} km`;
}
