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
