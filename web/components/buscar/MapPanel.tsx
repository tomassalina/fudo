import type { Merchant } from "@/lib/types";

// Deterministic pseudo-positions for the fake pins — purely decorative,
// not real geocoding. Keeps the panel visually alive without a map library.
const PIN_POSITIONS = [
  { top: "18%", left: "28%" },
  { top: "34%", left: "62%" },
  { top: "52%", left: "22%" },
  { top: "64%", left: "70%" },
  { top: "78%", left: "40%" },
  { top: "24%", left: "82%" },
  { top: "46%", left: "48%" },
  { top: "70%", left: "14%" },
];

/**
 * Static, styled stand-in for the real map. The PRD calls for OpenStreetMap
 * + CartoDB Dark Matter tiles with real pins — wiring an actual interactive
 * map (Leaflet et al.) is deferred, it's real work that doesn't belong in
 * this low-priority SSR pass. This just keeps the two-panel layout honest
 * about what's coming.
 */
export function MapPanel({ merchants }: { merchants: Merchant[] }) {
  const pins = merchants.slice(0, PIN_POSITIONS.length);

  return (
    <div className="relative h-full min-h-[280px] overflow-hidden rounded-2xl border border-border bg-[#101119]">
      {/* Abstract city-block pattern, evoking the dark map tiles without loading any. */}
      <div className="absolute inset-0 opacity-70">
        <div className="absolute left-0 top-[28%] h-[3px] w-full bg-white/10" />
        <div className="absolute left-0 top-[58%] h-[4px] w-full -rotate-2 bg-white/10" />
        <div className="absolute left-[22%] top-0 h-full w-[3px] bg-white/10" />
        <div className="absolute left-[64%] top-0 h-full w-[4px] bg-white/10" />
        <div className="absolute left-[30%] top-[8%] h-[38%] w-[26%] rounded-sm bg-white/[0.06]" />
        <div className="absolute left-[70%] top-[36%] h-[30%] w-[20%] rounded-sm bg-white/[0.06]" />
        <div className="absolute left-[8%] top-[62%] h-[26%] w-[16%] rounded-sm bg-white/[0.06]" />
      </div>

      {pins.map((merchant, index) => (
        <span
          key={merchant.id}
          title={merchant.name}
          className="absolute flex h-6 w-6 -translate-x-1/2 -translate-y-1/2 items-center justify-center rounded-full border-2 border-[#101119] bg-accent shadow-md shadow-black/40"
          style={PIN_POSITIONS[index]}
        />
      ))}

      <div className="absolute inset-x-3 bottom-3 rounded-xl border border-border bg-surface/90 px-3 py-2 text-center text-[12px] text-foreground-muted backdrop-blur">
        Mapa interactivo próximamente — ubicaciones simuladas en Palermo.
      </div>
    </div>
  );
}
