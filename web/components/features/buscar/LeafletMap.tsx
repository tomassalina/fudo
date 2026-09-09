"use client";

// The real Leaflet map. This file is only ever loaded client-side (see
// MapPanel.tsx, which imports it via next/dynamic with `ssr: false`) —
// Leaflet reads `window`/`document` at module-evaluation time and throws
// under SSR/prerendering otherwise.

import { useEffect, useMemo, useRef, useState } from "react";
import { MapContainer, Marker, Popup, TileLayer, useMapEvents } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import "./leaflet-map.css";
import type { Merchant, MerchantType } from "@/lib/types";
import {
  MERCHANT_TYPE_BADGE,
  MERCHANT_TYPE_LABELS,
  USER_LOCATION,
} from "@/lib/mock/merchants";
import { MerchantMapCard } from "./MerchantMapCard";

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

const PIN_CIRCLE_SIZE = 38;
const PIN_TAIL_SIZE = 8;
const PIN_WIDTH = 160;
const PIN_LABEL_BLOCK = 24;

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

// Leaflet's default marker icon references image files by relative path,
// which breaks under webpack/Turbopack bundling (broken-image icons) — a
// well-known Leaflet+bundler gotcha, sidestepped here (as before) with a
// CSS-only L.divIcon instead of patching L.Icon.Default's asset URLs.
//
// Unlike the earlier flat accent-colored dot, this builds one icon per
// merchant *type* — the same Material Symbols glyph + tint MerchantCard's
// type chip already uses (MERCHANT_TYPE_BADGE: orange restaurant, green
// cafe, violet bar, etc.), not a generic pin, per the design reference. A
// small CSS-triangle tail anchors the icon at the merchant's exact
// coordinate the way a real map-pin drop shape does. `withLabel` additionally
// renders the type's Spanish label in a pill below the pin — the phone
// full-screen map has the vertical room for it; the compact desktop split
// view (many pins, much less height) doesn't, per the design reference.
function createMerchantIcon(type: MerchantType, withLabel: boolean): L.DivIcon {
  const badge = MERCHANT_TYPE_BADGE[type];
  const label = MERCHANT_TYPE_LABELS[type];
  const anchorY = PIN_CIRCLE_SIZE + PIN_TAIL_SIZE;
  const totalHeight = withLabel ? anchorY + PIN_LABEL_BLOCK : anchorY;

  return L.divIcon({
    className: "",
    html: `
      <span class="fudo-map-pin" style="--fudo-pin-color:${badge.color}">
        <span class="fudo-map-pin__circle">
          <span class="material-symbols" aria-hidden="true">${badge.icon}</span>
        </span>
        <span class="fudo-map-pin__tail" aria-hidden="true"></span>
        ${withLabel ? `<span class="fudo-map-pin__label">${escapeHtml(label)}</span>` : ""}
      </span>
    `,
    iconSize: [PIN_WIDTH, totalHeight],
    iconAnchor: [PIN_WIDTH / 2, anchorY],
    popupAnchor: [0, -anchorY],
  });
}

// Excludes merchants with a non-finite latitude/longitude (see
// `parseCoordinate` in lib/api/merchants.ts, which already `console.warn`s
// per merchant when this happens) instead of plotting them at a fake-valid
// `(0, 0)` — Leaflet would also throw when handed NaN coordinates, so this
// doubles as a crash guard.
function hasValidCoordinates(merchant: Merchant): boolean {
  return Number.isFinite(merchant.latitude) && Number.isFinite(merchant.longitude);
}

// Debounce window between the map settling (pan/zoom finished) and actually
// narrowing the pins to the new visible area — long enough that a quick
// flick or a couple of successive small pans doesn't recompute (and flash
// the "Buscando en la zona…" chip) on every one of them, short enough to
// still read as responsive. `GET /api/v1/merchants` has no bounding-box/
// lat-lng-range filter today (confirmed against
// backend/app/controllers/api/v1/merchants_controller.rb — only
// `neighborhood`, `type`, `tags`, `price_per_person`), so there's no real
// network trip to wait on yet; this filters the already-fetched `merchants`
// array (the page's whole current result set, ~30 rows for this MVP, no
// pagination at that layer either) by `map.getBounds()` instead. Same
// debounced "pan → wait → narrow the pins" UX either way, and it drops onto
// a real bbox endpoint later (swap the local `.filter` below for a fetch)
// without changing this component's shape.
const ZONE_DEBOUNCE_MS = 600;

/**
 * Narrows the map's pins to whatever falls inside the current viewport,
 * Airbnb-style, instead of always plotting every merchant regardless of
 * pan/zoom — see the file-level comment above `ZONE_DEBOUNCE_MS` for why
 * this filters the already-fetched list rather than issuing a new request.
 * Rendered as a child of `<MapContainer>` (not a hook called by LeafletMap
 * directly) because `useMapEvents` requires the Leaflet map context
 * react-leaflet only provides to `MapContainer`'s own children.
 */
function ZoneWatcher({
  merchants,
  onVisibleChange,
  onSearchingChange,
}: {
  merchants: Merchant[];
  onVisibleChange: (visible: Merchant[]) => void;
  onSearchingChange: (searching: boolean) => void;
}) {
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const map = useMapEvents({
    movestart() {
      if (debounceRef.current) clearTimeout(debounceRef.current);
      onSearchingChange(true);
    },
    moveend() {
      if (debounceRef.current) clearTimeout(debounceRef.current);
      debounceRef.current = setTimeout(() => {
        const bounds = map.getBounds();
        onVisibleChange(
          merchants.filter((merchant) => bounds.contains([merchant.latitude, merchant.longitude])),
        );
        onSearchingChange(false);
      }, ZONE_DEBOUNCE_MS);
    },
  });

  // The result set itself can change with no pan/zoom involved (a filter or
  // search changed upstream in app/buscar/page.tsx) — re-narrow immediately
  // against the *current* view in that case instead of waiting on the next
  // pan, and with no debounce/chip: this is a fresh dataset landing, not the
  // visitor moving around an existing one.
  useEffect(() => {
    const bounds = map.getBounds();
    onVisibleChange(
      merchants.filter((merchant) => bounds.contains([merchant.latitude, merchant.longitude])),
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps -- intentionally re-runs only when `merchants` itself changes; `map`/the callbacks are stable for the component's lifetime
  }, [merchants]);

  useEffect(
    () => () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    },
    [],
  );

  return null;
}

export interface LeafletMapProps {
  merchants: Merchant[];
  /** Show the type-label pill under each pin (phone full-screen map). Omitted on the compact desktop split view. */
  showLabels?: boolean;
}

export function LeafletMap({ merchants, showLabels = false }: LeafletMapProps) {
  const center: [number, number] = [
    USER_LOCATION.latitude,
    USER_LOCATION.longitude,
  ];
  // `useMemo`, not a plain `.filter()` per render: ZoneWatcher's effect below
  // depends on this array by reference (it needs to know when the *actual*
  // result set changes vs. just re-narrowing on pan) — an unmemoized new
  // array every render would make that effect fire every render, call
  // `onVisibleChange`, cause this state update, re-render, produce yet
  // another new array, and loop forever (confirmed live: this exact shape
  // threw React's "Maximum update depth exceeded" before this memo was
  // added).
  const allMarkers = useMemo(() => merchants.filter(hasValidCoordinates), [merchants]);

  // Only the merchants currently inside the map's viewport get a pin —
  // ZoneWatcher (rendered below, inside <MapContainer>) keeps this narrowed
  // to `map.getBounds()` on pan/zoom, debounced. Seeded with `allMarkers` so
  // there's a full set of pins to show before the map's first real bounds
  // are known (its very first render, pre-mount) rather than an empty map.
  const [markers, setMarkers] = useState(allMarkers);
  const [searchingZone, setSearchingZone] = useState(false);

  // Lets a pin's own popup card "next result" arrow open the following pin's
  // popup/pan there, without lifting a "selected merchant" React state up —
  // Leaflet's Popup has `autoClose: true` by default, so opening the next
  // marker's popup already closes the current one on its own. Only cycles
  // through the *visible* pins — the ones with no rendered `<Marker>` (out of
  // the current viewport) have no popup to open anyway.
  const markerRefs = useRef(new Map<number, L.Marker>());

  function registerMarker(id: number, instance: L.Marker | null) {
    if (instance) markerRefs.current.set(id, instance);
    else markerRefs.current.delete(id);
  }

  function goToMerchant(id: number) {
    markerRefs.current.get(id)?.openPopup();
  }

  return (
    <>
      <MapContainer
        center={center}
        zoom={14}
        // Real zoom in every input mode the map's own reference points to:
        // mouse wheel (scrollWheelZoom) and pinch (touchZoom, Leaflet's
        // default — listed explicitly so it doesn't silently regress) on
        // touch devices, plus the visible +/- control (zoomControl, also
        // Leaflet's default). scrollWheelZoom was previously off to avoid
        // hijacking page scroll inside the old small inline panel; the map is
        // now either the dominant desktop column or the full phone screen, so
        // capturing the wheel while hovering it is the expected interactive-map
        // behavior instead.
        scrollWheelZoom
        touchZoom
        zoomControl
        className="h-full w-full"
      >
        <TileLayer url={TILE_URL} attribution={TILE_ATTRIBUTION} />
        <ZoneWatcher
          merchants={allMarkers}
          onVisibleChange={setMarkers}
          onSearchingChange={setSearchingZone}
        />
        {markers.map((merchant, index) => {
          const next = markers.length > 1 ? markers[(index + 1) % markers.length] : null;
          return (
            <Marker
              key={merchant.id}
              position={[merchant.latitude, merchant.longitude]}
              icon={createMerchantIcon(merchant.type, showLabels)}
              ref={(instance) => registerMarker(merchant.id, instance)}
            >
              {/* closeButton={false}: MerchantMapCard renders its own close
                  button styled for Fudo's dark surface instead of Leaflet's
                  default white "×". */}
              <Popup closeButton={false} minWidth={248} maxWidth={280}>
                <MerchantMapCard
                  merchant={merchant}
                  onClose={() => markerRefs.current.get(merchant.id)?.closePopup()}
                  onNext={next ? () => goToMerchant(next.id) : undefined}
                />
              </Popup>
            </Marker>
          );
        })}
      </MapContainer>

      {/* Same pill treatment as AiChips' tag chips (border-border/bg-surface,
          rounded-full, 13px semibold) — a status chip instead of a filter
          toggle, so it's centered and non-interactive rather than a row of
          left-aligned buttons. z-[1000]: above Leaflet's own panes (which top
          out around z-index 650) and its zoom control. */}
      {searchingZone ? (
        <div className="pointer-events-none absolute inset-x-0 top-3 z-[1000] flex justify-center">
          <span className="inline-flex items-center gap-1.5 rounded-full border border-border bg-surface px-3.5 py-1.5 text-[13px] font-semibold text-foreground shadow-lg shadow-black/30">
            <span aria-hidden className="material-symbols animate-spin text-[15px]">
              progress_activity
            </span>
            Buscando en la zona…
          </span>
        </div>
      ) : null}
    </>
  );
}
