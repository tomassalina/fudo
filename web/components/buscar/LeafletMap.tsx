"use client";

// The real Leaflet map. This file is only ever loaded client-side (see
// MapPanel.tsx, which imports it via next/dynamic with `ssr: false`) —
// Leaflet reads `window`/`document` at module-evaluation time and throws
// under SSR/prerendering otherwise.

import Link from "next/link";
import { MapContainer, Marker, Popup, TileLayer } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import "./leaflet-map.css";
import type { Merchant } from "@/lib/types";
import { USER_LOCATION } from "@/lib/mock/merchants";

// CartoDB Dark Matter tiles — the exact tile URL + attribution the PRD asks
// for ("OpenStreetMap, tiles CartoDB Dark Matter"). Attribution string per
// CartoDB's documented Leaflet usage (github.com/CartoDB/basemap-styles):
// credit both OSM contributors and CARTO.
//
// Verified live (curl'd a tile + carto.com/basemaps/apikey docs): CARTO now
// gates basemaps.cartocdn.com behind a free API key — unauthenticated
// requests still return 200 but the tile is a plain dark square stamped
// "API KEY REQUIRED", not a broken/failed request. Appending `?key=` when
// NEXT_PUBLIC_CARTO_API_KEY is set (see .env.example) removes the watermark;
// without one the map still renders (pins, popups, zoom all work), just with
// that overlay until a key is added — free, no approval queue, key emailed
// immediately.
const CARTO_API_KEY = process.env.NEXT_PUBLIC_CARTO_API_KEY;
const TILE_URL = CARTO_API_KEY
  ? `https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png?key=${CARTO_API_KEY}`
  : "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png";
const TILE_ATTRIBUTION =
  '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>';

// Leaflet's default marker icon references image files by relative path,
// which breaks under webpack/Turbopack bundling (broken-image icons) — a
// well-known Leaflet+bundler gotcha. Sidestepped entirely here by using a
// CSS-only L.divIcon (no external image asset to resolve) styled to match
// the app's existing accent-colored pin dot from the old placeholder panel,
// instead of patching L.Icon.Default's asset URLs.
const merchantIcon = L.divIcon({
  className: "",
  html: '<span class="block h-5 w-5 rounded-full border-2 border-[#101119] bg-accent shadow-md shadow-black/40"></span>',
  iconSize: [20, 20],
  iconAnchor: [10, 10],
  popupAnchor: [0, -10],
});

export function LeafletMap({ merchants }: { merchants: Merchant[] }) {
  const center: [number, number] = [
    USER_LOCATION.latitude,
    USER_LOCATION.longitude,
  ];

  return (
    <MapContainer
      center={center}
      zoom={14}
      scrollWheelZoom={false}
      className="h-full w-full"
    >
      <TileLayer url={TILE_URL} attribution={TILE_ATTRIBUTION} />
      {merchants.map((merchant) => (
        <Marker
          key={merchant.id}
          position={[merchant.latitude, merchant.longitude]}
          icon={merchantIcon}
        >
          <Popup>
            {/* Color comes from leaflet-map.css (.leaflet-popup-content a) —
                leaflet.css's own `.leaflet-container a` rule outranks a
                plain Tailwind utility class on specificity. */}
            <Link
              href={`/restaurantes/${merchant.id}`}
              className="font-semibold hover:underline"
            >
              {merchant.name}
            </Link>
          </Popup>
        </Marker>
      ))}
    </MapContainer>
  );
}
