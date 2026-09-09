"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import type { MerchantType } from "@/lib/types";
import { Sheet } from "@/components/ui/Sheet";
import { buttonVariants } from "@/components/ui/Button";
import { cn } from "@/lib/utils/cn";
import { buscarHref, countActiveFilters, type BuscarParams } from "@/lib/utils/buscar-href";
import { FilterCategoryTabs } from "./FilterCategoryTabs";
import { FilterOptionSheet } from "./FilterOptionSheet";
import { buildFilterRows, clearedDraft, type FilterCategoryKey } from "./filter-rows";

// Phone-layout filters: a "tune" trigger button (with the active-filter-
// count badge) that opens the full-height "Filtros" bottom sheet from the
// task's reference screenshot — 4 category pill tabs, a scrollable list of
// icon+label+value rows per category, each row opening its own smaller
// options sub-sheet, and a pinned Limpiar/Aplicar footer. Matches
// `filtersOpen`/`optOpen` in `docs/design-reference/Fudo App.dc.html`.
//
// Edits are staged in local `draft` state (seeded from `current` on open)
// instead of navigating on every tap — same as the reference's
// `fDraft`/`applyFilters`/`clearAllFilters` split: "Limpiar" only resets the
// draft (sheet stays open), "Aplicar" is what actually commits it to the
// URL and closes the sheet. FilterSidebar (the wide-layout column) keeps
// the instant-navigation `<Link>` behavior — deliberately not shared with
// this component, since the two chrome styles genuinely differ.

interface PhoneFilterSheetProps {
  current: BuscarParams;
  activeType: MerchantType | null;
  availableTypes: MerchantType[];
  availableHoods: string[];
  isAuthenticated: boolean;
}

export function PhoneFilterSheet({
  current,
  availableTypes,
  availableHoods,
  isAuthenticated,
}: PhoneFilterSheetProps) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState<BuscarParams>(current);
  const [cat, setCat] = useState<FilterCategoryKey>("basico");
  const [optionRowId, setOptionRowId] = useState<string | null>(null);

  const activeCount = countActiveFilters(current);
  const rowsByCategory = buildFilterRows(availableTypes, availableHoods);
  const rows = rowsByCategory[cat];
  const activeRow = optionRowId
    ? Object.values(rowsByCategory)
        .flat()
        .find((row) => row.id === optionRowId)
    : null;

  function openSheet() {
    setDraft(current);
    setCat("basico");
    setOptionRowId(null);
    setOpen(true);
  }

  function closeSheet() {
    setOpen(false);
    setOptionRowId(null);
  }

  function apply() {
    router.push(buscarHref(draft));
    closeSheet();
  }

  function clearAll() {
    setDraft((prev) => clearedDraft(prev));
  }

  function toggleHideVisited() {
    setDraft((prev) => ({ ...prev, hideVisited: prev.hideVisited === "1" ? "" : "1" }));
  }

  return (
    <>
      <button
        type="button"
        onClick={openSheet}
        aria-label="Filtros"
        className="relative flex h-[42px] w-[42px] flex-none items-center justify-center rounded-full border border-border bg-surface shadow-[inset_0_1px_0_var(--highlight)] transition-[border-color] duration-200 hover:border-accent/50 active:scale-95"
      >
        <span aria-hidden className="material-symbols text-[20px] text-foreground">
          tune
        </span>
        {activeCount > 0 ? (
          <span className="absolute -right-1 -top-1 flex h-[18px] min-w-[18px] items-center justify-center rounded-full border-2 border-background bg-accent px-1 text-[10.5px] font-bold text-white">
            {activeCount}
          </span>
        ) : null}
      </button>

      <Sheet
        open={open}
        onClose={closeSheet}
        title="Filtros"
        className="h-[calc(100dvh-110px)]"
        bodyClassName="flex-1 overflow-y-auto px-5 pt-4"
        headerExtra={
          <div className="flex gap-2">
            <span
              className={cn(
                "inline-flex flex-none items-center rounded-full border px-4 py-2.5 text-[13px] font-semibold",
                activeCount > 0
                  ? "border-transparent bg-gradient-to-b from-cta-from to-cta-to text-white shadow-cta"
                  : "border-border bg-surface text-foreground-faint",
              )}
            >
              {activeCount === 1 ? "1 filtro activo" : `${activeCount} filtros activos`}
            </span>
            {isAuthenticated ? (
              <button
                type="button"
                onClick={toggleHideVisited}
                aria-pressed={draft.hideVisited === "1"}
                className={cn(
                  "flex flex-none items-center gap-1.5 whitespace-nowrap rounded-full border px-3.5 py-2.5 text-[13px] font-semibold transition-colors",
                  draft.hideVisited === "1"
                    ? "border-accent/40 bg-accent-soft text-accent-light"
                    : "border-border bg-surface text-foreground-muted",
                )}
              >
                <span aria-hidden className="material-symbols text-[17px]">
                  visibility_off
                </span>
                Ocultar visitados
              </button>
            ) : null}
          </div>
        }
        footer={
          <div className="flex gap-2.5">
            <button
              type="button"
              onClick={clearAll}
              className={buttonVariants({ variant: "secondary", size: "lg", className: "flex-1" })}
            >
              Limpiar
            </button>
            <button
              type="button"
              onClick={apply}
              className={buttonVariants({ variant: "primary", size: "lg", className: "flex-[1.4]" })}
            >
              Aplicar
            </button>
          </div>
        }
      >
        <div className="flex flex-col gap-4 pb-2">
          <FilterCategoryTabs active={cat} onChange={setCat} />

          <div className="flex flex-col">
            {rows.map((row) => {
              const value = row.getValue(draft);
              const label = row.options.find((o) => o.value === value)?.label ?? "Cualquiera";
              const isDefault = value === "";
              return (
                <button
                  key={row.id}
                  type="button"
                  onClick={() => setOptionRowId(row.id)}
                  className="flex w-full items-center gap-3 border-0 border-b border-border bg-transparent px-0.5 py-4 text-left transition-colors hover:bg-highlight"
                >
                  <span aria-hidden className="material-symbols text-[20px] text-foreground-muted">
                    {row.icon}
                  </span>
                  <span className="flex-1 text-[14.5px] text-foreground">{row.label}</span>
                  <span
                    className={cn(
                      "text-[13.5px] font-semibold",
                      isDefault ? "text-foreground-faint" : "text-accent-light",
                    )}
                  >
                    {label}
                  </span>
                  <span aria-hidden className="material-symbols text-[18px] text-foreground-faint">
                    chevron_right
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      </Sheet>

      {activeRow ? (
        <FilterOptionSheet
          title={activeRow.label}
          options={activeRow.options}
          value={activeRow.getValue(draft)}
          onPick={(value) => {
            setDraft((prev) => activeRow.setValue(prev, value));
            setOptionRowId(null);
          }}
          onClose={() => setOptionRowId(null)}
        />
      ) : null}
    </>
  );
}
