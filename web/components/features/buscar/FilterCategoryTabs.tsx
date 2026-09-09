"use client";

import { cn } from "@/lib/utils/cn";
import { FILTER_CATEGORIES, type FilterCategoryKey } from "./filter-rows";

// The 4 category pills at the top of the filters sheet body (`filterCats`
// in the design reference) — a horizontally-scrollable icon+label switch
// between the row groups below, active tab styled as a solid CTA-gradient
// pill (same tokens as the sheet's "Aplicar" button), inactive as a plain
// surface card.

interface FilterCategoryTabsProps {
  active: FilterCategoryKey;
  onChange: (key: FilterCategoryKey) => void;
}

export function FilterCategoryTabs({ active, onChange }: FilterCategoryTabsProps) {
  return (
    <div className="flex gap-2 overflow-x-auto">
      {FILTER_CATEGORIES.map((cat) => {
        const isActive = cat.key === active;
        return (
          <button
            key={cat.key}
            type="button"
            onClick={() => onChange(cat.key)}
            aria-pressed={isActive}
            className={cn(
              "flex w-[78px] flex-none flex-col items-center gap-1 rounded-2xl border px-1 py-3 transition-colors",
              isActive
                ? "border-transparent bg-gradient-to-b from-cta-from to-cta-to text-white shadow-cta"
                : "border-border bg-surface text-foreground-muted shadow-[inset_0_1px_0_var(--highlight)]",
            )}
          >
            <span aria-hidden className="material-symbols text-[19px]">
              {cat.icon}
            </span>
            <span className="whitespace-nowrap text-[12px] font-semibold">{cat.label}</span>
          </button>
        );
      })}
    </div>
  );
}
