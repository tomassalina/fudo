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
//
// `counts` (product-owner request — neither `.dc.html` reference shows a
// per-tab count, only the single total "N filtros activos" pill
// FilterSidebar/PhoneFilterSheet already render elsewhere; see
// filter-rows.ts's `countActiveFiltersByCategory` doc comment) adds a small
// numeral badge per tab showing how many filters are active in that
// category, on BOTH surfaces. Modeled on this app's own existing
// small-numeral-badge convention (the phone "tune" trigger's active-count
// badge in PhoneFilterSheet.tsx — accent background, white text,
// rounded-full). Sidebar renders it inline at the end of the pill's row
// (room to spare in its 2-column grid); sheet renders it as a small badge
// overlapping the pill's top-right corner instead, since the sheet's icon-
// above-label pills have no inline slot for it.

interface FilterCategoryTabsProps {
  active: FilterCategoryKey;
  onChange: (key: FilterCategoryKey) => void;
  variant?: "sheet" | "sidebar";
  counts?: Partial<Record<FilterCategoryKey, number>>;
}

export function FilterCategoryTabs({
  active,
  onChange,
  variant = "sheet",
  counts,
}: FilterCategoryTabsProps) {
  if (variant === "sidebar") {
    return (
      <div className="grid grid-cols-2 gap-2">
        {FILTER_CATEGORIES.map((cat) => {
          const isActive = cat.key === active;
          const count = counts?.[cat.key] ?? 0;
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
              {count > 0 ? (
                <span
                  className={cn(
                    "ml-auto flex h-[16px] min-w-[16px] flex-none items-center justify-center rounded-full px-1 text-[9.5px] font-bold",
                    isActive ? "bg-white/25 text-white" : "bg-accent text-white",
                  )}
                >
                  {count}
                </span>
              ) : null}
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
        const count = counts?.[cat.key] ?? 0;
        return (
          <button
            key={cat.key}
            type="button"
            onClick={() => onChange(cat.key)}
            aria-pressed={isActive}
            className={cn(
              "relative flex w-[78px] flex-none flex-col items-center gap-1 rounded-2xl border px-1 py-3 transition-colors",
              isActive
                ? "border-transparent bg-gradient-to-b from-cta-from to-cta-to text-white shadow-cta"
                : "border-border bg-surface text-foreground-muted shadow-[inset_0_1px_0_var(--highlight)]",
            )}
          >
            <span aria-hidden className="material-symbols text-[19px]">
              {cat.icon}
            </span>
            <span className="whitespace-nowrap text-[12px] font-semibold">{cat.label}</span>
            {count > 0 ? (
              <span
                className={cn(
                  "absolute -right-1 -top-1 flex h-[16px] min-w-[16px] flex-none items-center justify-center rounded-full px-1 text-[9.5px] font-bold",
                  isActive ? "bg-white text-accent" : "bg-accent text-white",
                )}
              >
                {count}
              </span>
            ) : null}
          </button>
        );
      })}
    </div>
  );
}
