"use client";

// Real consumer geolocation — backs the header's "Activar ubicación" pill
// (components/layout/LocationButton.tsx, mounted from both
// components/layout/Header.tsx on phone and WideNav on wide) and the
// per-merchant distance shown on Inicio/Buscar/Detalle
// (lib/location/use-merchant-distance.ts). See
// docs/visual-qa-report.md, "1. Inicio", hallazgo #1/#3 — the header didn't
// exist yet, so there was no way to ever populate this and every card fell
// back to a hardcoded "0 km".
//
// Same external-store pattern lib/session/session-provider.tsx documents
// for the exact same reason: state that must survive a reload (localStorage)
// and must not cause a server/first-paint hydration mismatch
// (`getServerSnapshot` always reports "idle", the same "server and first
// client paint render the logged-out/no-location state" trick
// use-viewport.ts and session-provider.tsx both use). A full Context
// provider isn't needed here — unlike session there's exactly one producer
// (the browser's Geolocation API) and every consumer just wants to read the
// latest coordinates, so a bare module-level store is the smaller diff.

import { useCallback, useSyncExternalStore } from "react";

export interface Coordinates {
  latitude: number;
  longitude: number;
}

export type LocationStatus =
  /** Never asked yet (nothing in localStorage either). */
  | "idle"
  /** Browser granted permission — `coords` is set. */
  | "granted"
  /** Browser permission was denied, or the request otherwise failed
   * (timeout, position unavailable). Handled gracefully: the button just
   * goes back to its "Activar ubicación" look, same as `idle`. */
  | "denied"
  /** `navigator.geolocation` doesn't exist (very old browser, non-browser
   * environment, or a context Geolocation refuses, e.g. non-HTTPS). */
  | "unsupported";

export interface LocationState {
  coords: Coordinates | null;
  status: LocationStatus;
}

const STORAGE_KEY = "fudo:user-location";

type Listener = () => void;

let state: LocationState = { coords: null, status: "idle" };
let hydrated = false;
const listeners = new Set<Listener>();

function notify() {
  for (const listener of listeners) listener();
}

function subscribe(listener: Listener) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function isCoordinates(value: unknown): value is Coordinates {
  return (
    typeof value === "object" &&
    value !== null &&
    typeof (value as Coordinates).latitude === "number" &&
    typeof (value as Coordinates).longitude === "number"
  );
}

function readStoredState(): LocationState {
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return { coords: null, status: "idle" };
    const parsed = JSON.parse(raw);
    return isCoordinates(parsed)
      ? { coords: parsed, status: "granted" }
      : { coords: null, status: "idle" };
  } catch {
    // Corrupted or blocked storage (private mode, quota) — fall back to
    // "not activated yet" instead of throwing during render.
    return { coords: null, status: "idle" };
  }
}

function getSnapshot(): LocationState {
  if (!hydrated) {
    state = readStoredState();
    hydrated = true;
  }
  return state;
}

// A stable module-level constant, not a fresh object literal per call:
// `useSyncExternalStore` compares consecutive `getServerSnapshot()` results
// with `Object.is`, and a new `{ coords: null, status: "idle" }` on every
// invocation fails that check — React logs "The result of getServerSnapshot
// should be cached to avoid an infinite loop" during hydration (confirmed
// live: it fires on every phone/wide route that mounts the header, since
// LocationButton is mounted from both). `state`'s own initial value above
// is a separate object and intentionally not reused here — `state` is
// mutable (reassigned by `setState`) while this one must never change.
const SERVER_SNAPSHOT: LocationState = { coords: null, status: "idle" };

function getServerSnapshot(): LocationState {
  return SERVER_SNAPSHOT;
}

function setState(next: LocationState) {
  state = next;
  hydrated = true;
  try {
    if (next.coords) {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(next.coords));
    } else {
      window.localStorage.removeItem(STORAGE_KEY);
    }
  } catch {
    // Storage blocked/full — state still updates in memory for this tab,
    // it just won't survive a reload.
  }
  notify();
}

// Cheap city-scale accuracy is enough for "which neighborhood is closest"
// distance chips — no need to drain the battery with GPS-grade accuracy,
// and a 5-minute cache means re-opening the app doesn't always re-prompt.
const GEOLOCATION_OPTIONS: PositionOptions = {
  enableHighAccuracy: false,
  timeout: 10_000,
  maximumAge: 5 * 60 * 1000,
};

export interface UseLocationResult extends LocationState {
  /**
   * Prompts the browser's geolocation permission (or reads the cached
   * position) and stores the result. Denied/unsupported/error all resolve
   * into `status` instead of throwing, so callers never need a try/catch —
   * see the "denied" case above for why that matters to the UI.
   */
  requestLocation: () => void;
  /** Turns location back off — clears the stored coordinates and returns to
   * "idle" so the button goes back to "Activar ubicación". This does not
   * (and cannot, from JS) revoke the browser's own permission grant; it
   * just stops the app from using the last known position. */
  clearLocation: () => void;
}

export function useLocation(): UseLocationResult {
  const snapshot = useSyncExternalStore(
    subscribe,
    getSnapshot,
    getServerSnapshot,
  );

  const requestLocation = useCallback(() => {
    if (typeof navigator === "undefined" || !navigator.geolocation) {
      setState({ coords: null, status: "unsupported" });
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (position) => {
        setState({
          coords: {
            latitude: position.coords.latitude,
            longitude: position.coords.longitude,
          },
          status: "granted",
        });
      },
      () => {
        setState({ coords: null, status: "denied" });
      },
      GEOLOCATION_OPTIONS,
    );
  }, []);

  const clearLocation = useCallback(() => {
    setState({ coords: null, status: "idle" });
  }, []);

  return { ...snapshot, requestLocation, clearLocation };
}
