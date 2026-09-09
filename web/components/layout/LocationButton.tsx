"use client";

// The "Activar ubicación" pill — shared between the phone Header
// (components/layout/Header.tsx) and WideNav's sticky top bar, since both
// design references render the exact same button (compare
// docs/design-reference/Fudo App.dc.html's `toggleLoc` button, ~line 182,
// with docs/design-reference/Fudo Customers.dc.html's, ~line 173: same
// icon/label/style logic, just embedded in two different chrome layouts).
//
// Only the icon/color reacts to state, per this feature's brief — the
// reference's own label swap to a fabricated neighborhood ("Palermo, CABA")
// isn't reproduced: this app has no reverse-geocoding, and showing a
// hardcoded neighborhood name for the visitor's *real* position would be
// actively wrong instead of merely simplified.

import { useLocation } from "@/lib/location/use-location";
import { cn } from "@/lib/utils/cn";

export function LocationButton({ className }: { className?: string }) {
  const { coords, requestLocation, clearLocation } = useLocation();
  const active = coords !== null;

  return (
    <button
      type="button"
      onClick={active ? clearLocation : requestLocation}
      aria-pressed={active}
      className={cn(
        "flex flex-none items-center gap-1.5 rounded-full border border-border bg-surface py-1.5 pl-2.5 pr-3.5 shadow-[inset_0_1px_0_var(--highlight)] transition-colors duration-200 hover:border-accent/50",
        className,
      )}
    >
      <span
        aria-hidden
        className="material-symbols text-[17px]"
        style={{ color: active ? "var(--accent)" : "var(--foreground-muted)" }}
      >
        {active ? "my_location" : "location_disabled"}
      </span>
      <span
        className="whitespace-nowrap text-[12.5px] font-semibold"
        style={{ color: active ? "var(--accent)" : "var(--foreground-muted)" }}
      >
        {active ? "Ubicación activada" : "Activar ubicación"}
      </span>
    </button>
  );
}
