"use client";

import { cn } from "@/lib/utils/cn";

export interface SegmentedOption<T extends string> {
  key: T;
  label: string;
  /** Material Symbols glyph name. */
  icon: string;
}

/**
 * Shared active/inactive treatment for a segmented-control item — extracted
 * so `SegmentedControl` and `ResultModeToggle` (components/features/buscar/
 * ResultModeToggle.tsx, the pre-existing "Lugares/Platos" switch this
 * mirrors) never drift into two different "active pill" looks. `flex-1` is
 * on the caller, not baked in here, since `ResultModeToggle`'s items are
 * intrinsically sized (`px-4`) while this component's are evenly split.
 */
export function segmentedItemClassName(active: boolean): string {
  return cn(
    "flex items-center justify-center gap-1.5 rounded-full px-4 py-2.5 text-[13px] font-semibold transition-colors duration-200",
    active
      ? "bg-gradient-to-b from-cta-from to-cta-to text-white"
      : "text-foreground-faint hover:text-foreground",
  );
}

export interface SegmentedControlProps<T extends string> {
  options: SegmentedOption<T>[];
  value: T;
  onChange: (key: T) => void;
  /** Accessible name for the `role="tablist"` container. */
  label: string;
  className?: string;
}

/**
 * Generic pill tab-switcher — the first extraction of the segmented-control
 * pattern the design reuses everywhere (Buscar's "Lugares/Platos", the QR
 * sheet's "Mi QR/Escanear", and this one, Perfil's "Visitas/Favoritos/
 * Ajustes" — see `pTabs` in both `docs/design-reference/*.dc.html`).
 * Visually matches `ResultModeToggle` (gradient-filled active tab, per this
 * app's established style — the design reference itself uses a much
 * subtler `var(--surf2)` fill, see `docs/visual-qa-report.md` section 2
 * hallazgo #1, an already-accepted deviation), with real `role="tablist"`/
 * `"tab"`/`"tabpanel"` wiring like `QrSheetContent` uses for its own
 * hand-rolled switcher. Unlike `ResultModeToggle` (URL-driven `<Link>`s),
 * this drives plain component state via `onChange` — Perfil's tab isn't a
 * shareable/bookmarkable URL state today.
 */
export function SegmentedControl<T extends string>({
  options,
  value,
  onChange,
  label,
  className,
}: SegmentedControlProps<T>) {
  return (
    <div
      role="tablist"
      aria-label={label}
      className={cn(
        "flex gap-1 rounded-full border border-border bg-surface p-1",
        className,
      )}
    >
      {options.map((option) => {
        const active = option.key === value;
        return (
          <button
            key={option.key}
            type="button"
            role="tab"
            id={`segmented-tab-${option.key}`}
            aria-selected={active}
            aria-controls={`segmented-tabpanel-${option.key}`}
            onClick={() => onChange(option.key)}
            className={cn(segmentedItemClassName(active), "flex-1")}
          >
            <span aria-hidden className="material-symbols text-[17px]">
              {option.icon}
            </span>
            {option.label}
          </button>
        );
      })}
    </div>
  );
}
