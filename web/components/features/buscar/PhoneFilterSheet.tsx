"use client";

import { useState } from "react";
import Link from "next/link";
import type { MerchantType } from "@/lib/types";
import { Sheet } from "@/components/ui/Sheet";
import { buscarHref, countActiveFilters, type BuscarParams } from "@/lib/utils/buscar-href";
import { FilterFields } from "./FilterFields";

// Phone-layout filters: a "tune" trigger button (with the active-filter-count
// badge from the design's isList sheet) that opens the same FilterFields
// body inside the shared bottom Sheet, instead of the wide layout's
// always-visible sticky sidebar (FilterSidebar). Two components on purpose
// (per the task's explicit instruction) since the chrome genuinely differs —
// a modal sheet here, an in-flow column there — even though the filter
// fields themselves are shared.

interface PhoneFilterSheetProps {
  current: BuscarParams;
  activeType: MerchantType | null;
  availableTypes: MerchantType[];
  availableHoods: string[];
  isAuthenticated: boolean;
}

export function PhoneFilterSheet({
  current,
  activeType,
  availableTypes,
  availableHoods,
  isAuthenticated,
}: PhoneFilterSheetProps) {
  const [open, setOpen] = useState(false);
  const activeCount = countActiveFilters(current);

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
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

      <Sheet open={open} onClose={() => setOpen(false)} title="Filtros">
        <FilterFields
          current={current}
          activeType={activeType}
          availableTypes={availableTypes}
          availableHoods={availableHoods}
          isAuthenticated={isAuthenticated}
        />
        <Link
          href={buscarHref(current, {
            type: null,
            tags: null,
            price: null,
            hood: null,
            dist: null,
            hideVisited: null,
          })}
          scroll={false}
          onClick={() => setOpen(false)}
          className="mt-4 block rounded-full border border-border bg-transparent px-4 py-2.5 text-center text-[13.5px] font-semibold text-foreground transition-colors hover:border-accent/50"
        >
          Limpiar filtros
        </Link>
      </Sheet>
    </>
  );
}
