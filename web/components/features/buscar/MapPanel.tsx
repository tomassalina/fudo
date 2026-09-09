"use client";

// Real interactive map (OpenStreetMap + CartoDB Dark Matter tiles, per the
// PRD) replacing the earlier decorative placeholder. Leaflet reads
// `window`/`document` when its modules are evaluated, which breaks Next's
// SSR/prerendering — so the actual map (LeafletMap.tsx) is loaded via
// next/dynamic with `ssr: false`. That option only works inside a Client
// Component (Next.js's own docs: "ssr: false is not allowed with
// next/dynamic in Server Components"), hence this thin 'use client'
// wrapper.
import dynamic from "next/dynamic";
import type { Merchant } from "@/lib/types";

const LeafletMap = dynamic(
  () => import("./LeafletMap").then((mod) => mod.LeafletMap),
  {
    ssr: false,
    loading: () => (
      <div className="flex h-full items-center justify-center text-[12px] text-foreground-muted">
        Cargando mapa…
      </div>
    ),
  },
);

export function MapPanel({ merchants }: { merchants: Merchant[] }) {
  return (
    <div className="relative h-full min-h-[280px] overflow-hidden rounded-2xl border border-border bg-[#101119]">
      <LeafletMap merchants={merchants} />
    </div>
  );
}
