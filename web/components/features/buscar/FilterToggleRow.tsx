"use client";

import { cn } from "@/lib/utils/cn";
import type { BuscarParams } from "@/lib/utils/buscar-href";
import type { FilterToggleRowDef } from "./filter-rows";

// Inline multi-select badge row for a `FilterToggleRowDef` (currently only
// `dietRow` in filter-rows.ts) — shared as-is by PhoneFilterSheet and
// FilterSidebar. Unlike every select row on either surface, tapping a badge
// here toggles just that one value in place instead of opening a picker
// sub-sheet (phone) or a `<select>` (sidebar), so both surfaces render these
// same badges inline rather than each wrapping its own row-opens-a-picker
// chrome around it — there's no "sheet vs sidebar" chrome difference to
// preserve here, so one shared component instead of two parallel copies.
//
// Visual treatment matches the `aiChips` pill row in both design references
// (`aiOn`/`aiOff` in `docs/design-reference/Fudo App.dc.html`: rounded-full
// chip, tinted+bordered when selected, neutral when not), translated onto
// this app's own accent-soft/accent-light selected-chip tokens — the same
// ones `FilterOptionSheet` already uses for its own selected-option state —
// instead of the reference's literal orange values.

interface FilterToggleRowProps {
  row: FilterToggleRowDef;
  draft: BuscarParams;
  onToggle: (value: string) => void;
}

export function FilterToggleRow({ row, draft, onToggle }: FilterToggleRowProps) {
  const values = row.getValues(draft);

  return (
    <div className="flex flex-col gap-2.5 border-0 border-b border-border py-3.5 first:pt-0">
      <div className="flex items-center gap-2">
        <span aria-hidden className="material-symbols flex-none text-[19px] text-foreground-muted">
          {row.icon}
        </span>
        <span className="text-[13.5px] text-foreground">{row.label}</span>
      </div>
      <div className="flex flex-wrap gap-2 pl-[27px]">
        {row.options.map((option) => {
          const active = values.includes(option.value);
          return (
            <button
              key={option.value}
              type="button"
              onClick={() => onToggle(option.value)}
              aria-pressed={active}
              className={cn(
                "rounded-full border px-3.5 py-1.5 text-[12.5px] font-semibold transition-colors",
                active
                  ? "border-accent/45 bg-accent-soft text-accent-light"
                  : "border-border bg-surface text-foreground-muted hover:border-accent/30",
              )}
            >
              {option.label}
            </button>
          );
        })}
      </div>
    </div>
  );
}
