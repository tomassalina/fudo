"use client";

import { Sheet } from "@/components/ui/Sheet";
import { cn } from "@/lib/utils/cn";
import type { FilterOptionDef } from "./filter-rows";

// The nested "pick one option" sub-sheet a filter row opens — `optOpen` in
// `docs/design-reference/Fudo App.dc.html`: a smaller, content-sized sheet
// (max 62% of the viewport, vs. the near-full-height main filter sheet)
// stacked above it (`elevated`), listing every option for that one row as a
// checkable card. Picking an option applies it immediately and closes this
// sub-sheet, same as the reference's `pick` handler — there's no separate
// confirm step here, "Aplicar" on the main sheet is what commits the whole
// draft to the URL.

interface FilterOptionSheetProps {
  title: string;
  options: FilterOptionDef[];
  value: string;
  onPick: (value: string) => void;
  onClose: () => void;
}

export function FilterOptionSheet({
  title,
  options,
  value,
  onPick,
  onClose,
}: FilterOptionSheetProps) {
  return (
    <Sheet
      open
      onClose={onClose}
      title={title}
      elevated
      titleClassName="text-[19px]"
      className="max-h-[62vh]"
      bodyClassName="flex-1 overflow-y-auto px-5 pt-3.5 pb-6.5 flex flex-col gap-2.5"
    >
      {options.map((option) => {
        const active = option.value === value;
        return (
          <button
            key={option.value || "__default"}
            type="button"
            onClick={() => onPick(option.value)}
            aria-pressed={active}
            className={cn(
              "flex items-center justify-between gap-3 rounded-2xl border px-4 py-4 text-left text-[14.5px] text-foreground transition-colors",
              active
                ? "border-accent/45 bg-accent-soft"
                : "border-border bg-surface hover:border-accent/30",
            )}
          >
            <span>{option.label}</span>
            {active ? (
              <span
                aria-hidden
                className="flex h-[22px] w-[22px] flex-none items-center justify-center rounded-full bg-accent"
              >
                <span className="material-symbols text-[15px] text-white">check</span>
              </span>
            ) : null}
          </button>
        );
      })}
    </Sheet>
  );
}
