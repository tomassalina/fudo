"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import type { MerchantType } from "@/lib/types";
import { buscarHref, countActiveFilters, type BuscarParams } from "@/lib/utils/buscar-href";
import { buttonVariants } from "@/components/ui/Button";
import { cn } from "@/lib/utils/cn";
import { FilterCategoryTabs } from "./FilterCategoryTabs";
import { FilterToggleRow } from "./FilterToggleRow";
import {
  buildFilterRows,
  clearedDraft,
  countActiveFiltersByCategory,
  type FilterCategoryKey,
} from "./filter-rows";

// The wide-layout, always-visible sticky filter column — `position: sticky;
// top: 96px` in `docs/design-reference/Fudo Customers.dc.html`'s isList
// branch: "Filtros" title + active-count pill, the same 5 category tabs as
// the phone sheet, a row per filter dimension in the active category, and a
// pinned Limpiar/Aplicar footer.
//
// Shares its *data* with PhoneFilterSheet — same `buildFilterRows`/
// `FILTER_CATEGORIES` (filter-rows.ts) and the same staged-draft/Aplicar
// interaction model (edits accumulate in local `draft` state, only
// `router.push`ed on "Aplicar" — see that component's own doc comment for
// the rationale) — but with sidebar chrome instead of a bottom sheet: rows
// render as inline `<select>`s rather than opening a picker sub-sheet
// (there's no reason to spend a second sheet layer on a surface that
// already has room to show the control directly), and there's no
// "tune" trigger button to open/close, since the column is always on
// screen.

interface FilterSidebarProps {
  current: BuscarParams;
  activeType: MerchantType | null;
  availableTypes: MerchantType[];
  availableHoods: string[];
  isAuthenticated: boolean;
}

export function FilterSidebar({
  current,
  availableTypes,
  availableHoods,
  isAuthenticated,
}: FilterSidebarProps) {
  const router = useRouter();
  const [draft, setDraft] = useState<BuscarParams>(current);
  const [cat, setCat] = useState<FilterCategoryKey>("basico");

  // A fresh server navigation (new q/sort/etc. arriving via `current`, e.g.
  // from SearchBar or SortMenu, both of which still navigate instantly) must
  // reseed the draft — otherwise a stale, already-applied draft would sit in
  // front of the new `current` until the visitor happens to touch a sidebar
  // control again. Adjusted during render (React's documented "store info
  // from previous render" pattern, react.dev/learn/you-might-not-need-an-effect
  // — same rationale SearchResultsGrid's own doc comment gives for preferring
  // this over a `useEffect` + `setState`) rather than an effect, so the reset
  // lands in the same render `current` changed in instead of one tick later.
  const currentKey = JSON.stringify(current);
  const [prevCurrentKey, setPrevCurrentKey] = useState(currentKey);
  if (currentKey !== prevCurrentKey) {
    setPrevCurrentKey(currentKey);
    setDraft(current);
  }

  const draftCount = countActiveFilters(draft);
  const isDirty = JSON.stringify(draft) !== JSON.stringify(current);
  const rowsByCategory = buildFilterRows(availableTypes, availableHoods);
  const rows = rowsByCategory[cat];
  const categoryCounts = countActiveFiltersByCategory(rowsByCategory, draft);

  function apply() {
    router.push(buscarHref(draft));
  }

  function clearAll() {
    setDraft((prev) => clearedDraft(prev));
  }

  function toggleHideVisited() {
    setDraft((prev) => ({ ...prev, hideVisited: prev.hideVisited === "1" ? "" : "1" }));
  }

  return (
    <aside className="sticky top-24 flex max-h-[calc(100vh-7rem)] w-full min-w-0 flex-col gap-4 self-start overflow-hidden rounded-card border border-border bg-surface shadow-[inset_0_1px_0_var(--highlight)]">
      <div className="flex flex-col gap-4 overflow-y-auto p-[18px] pb-0">
        <div className="flex items-center justify-between">
          <h2 className="font-heading text-xl font-black text-foreground">Filtros</h2>
          <span
            className={cn(
              "whitespace-nowrap rounded-full border px-3 py-1 text-[12px] font-semibold",
              draftCount > 0
                ? "border-accent/35 bg-accent-soft text-accent-light"
                : "border-border bg-surface text-foreground-faint",
            )}
          >
            {draftCount === 1 ? "1 filtro activo" : `${draftCount} filtros activos`}
          </span>
        </div>

        {isAuthenticated ? (
          <button
            type="button"
            onClick={toggleHideVisited}
            aria-pressed={draft.hideVisited === "1"}
            className={cn(
              "flex items-center gap-1.5 self-start whitespace-nowrap rounded-full border px-3.5 py-2 text-[12.5px] font-semibold transition-colors",
              draft.hideVisited === "1"
                ? "border-accent/40 bg-accent-soft text-accent-light"
                : "border-border bg-surface text-foreground-muted",
            )}
          >
            <span aria-hidden className="material-symbols text-[16px]">
              visibility_off
            </span>
            Ocultar visitados
          </button>
        ) : null}

        <FilterCategoryTabs
          active={cat}
          onChange={setCat}
          variant="sidebar"
          counts={categoryCounts}
        />

        <div className="flex flex-col">
          {rows.map((row) => {
            if (row.kind === "toggle") {
              return (
                <FilterToggleRow
                  key={row.id}
                  row={row}
                  draft={draft}
                  onToggle={(value) => setDraft((prev) => row.toggleValue(prev, value))}
                />
              );
            }
            const value = row.getValue(draft);
            return (
              <label
                key={row.id}
                className="flex items-center gap-2 border-0 border-b border-border py-3.5 text-left first:pt-0"
              >
                <span aria-hidden className="material-symbols flex-none text-[19px] text-foreground-muted">
                  {row.icon}
                </span>
                <span className="flex-1 whitespace-nowrap text-[13.5px] text-foreground">
                  {row.label}
                </span>
                <span className="relative flex min-w-0 flex-none items-center">
                  <select
                    value={value}
                    onChange={(event) => setDraft((prev) => row.setValue(prev, event.target.value))}
                    className={cn(
                      "w-full max-w-[110px] cursor-pointer appearance-none truncate bg-transparent py-1 pl-2 pr-5 text-right text-[13px] font-semibold outline-none",
                      value ? "text-accent-light" : "text-foreground-faint",
                    )}
                  >
                    {row.options.map((option) => (
                      <option key={option.value} value={option.value} className="bg-surface text-foreground">
                        {option.label}
                      </option>
                    ))}
                  </select>
                  <span
                    aria-hidden
                    className="material-symbols pointer-events-none absolute right-0 text-[16px] text-foreground-faint"
                  >
                    chevron_right
                  </span>
                </span>
              </label>
            );
          })}
        </div>
      </div>

      <div className="flex flex-none gap-2.5 border-t border-border bg-surface p-[18px]">
        <button
          type="button"
          onClick={clearAll}
          className={buttonVariants({ variant: "secondary", size: "md", className: "flex-1" })}
        >
          Limpiar
        </button>
        <button
          type="button"
          onClick={apply}
          disabled={!isDirty}
          className={buttonVariants({
            variant: "primary",
            size: "md",
            className: "flex-[1.4] disabled:opacity-50",
          })}
        >
          Aplicar
        </button>
      </div>
    </aside>
  );
}
