"use client";

import { cn } from "@/lib/utils/cn";
import { FILTER_CATEGORIES, type FilterCategoryKey } from "./filter-rows";

// The category pills switching between the row groups below — same shared
// `FILTER_CATEGORIES` data and `active`/`onChange` contract for both
// surfaces, two different arrangements because the two chrome widths fit
// 5 tabs very differently (same "shared data, different chrome" split as
// MerchantCard's `layout: "row" | "card"`):
// - "sheet" (default, PhoneFilterSheet): `filterCats` in the design
//   reference — a horizontally-scrollable row of fixed-width, icon-above-
//   label pills. The full-width bottom sheet has room for this.
// - "sidebar" (FilterSidebar): the wide sidebar column (~220-280px) is too
//   narrow for 5 tabs in one scrollable row to read as anything but cut
//   off, so this variant matches the task's reference screenshot instead —
//   a 2-column grid of icon-then-label pills, wrapping to a 3rd row for the
//   5th (odd) tab.

interface FilterCategoryTabsProps {
  active: FilterCategoryKey;
  onChange: (key: FilterCategoryKey) => void;
  variant?: "sheet" | "sidebar";
}

export function FilterCategoryTabs({
  active,
  onChange,
  variant = "sheet",
}: FilterCategoryTabsProps) {
  if (variant === "sidebar") {
    return (
      <div className="grid grid-cols-2 gap-2">
        {FILTER_CATEGORIES.map((cat) => {
          const isActive = cat.key === active;
          return (
            <button
              key={cat.key}
              type="button"
              onClick={() => onChange(cat.key)}
              aria-pressed={isActive}
              className={cn(
                "flex items-center gap-1.5 rounded-xl border px-2.5 py-2 text-left transition-colors",
                isActive
                  ? "border-transparent bg-gradient-to-b from-cta-from to-cta-to text-white shadow-cta"
                  : "border-border bg-surface text-foreground-muted shadow-[inset_0_1px_0_var(--highlight)]",
              )}
            >
              <span aria-hidden className="material-symbols flex-none text-[16px]">
                {cat.icon}
              </span>
              <span className="truncate text-[12.5px] font-semibold">{cat.label}</span>
            </button>
          );
        })}
      </div>
    );
  }

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
