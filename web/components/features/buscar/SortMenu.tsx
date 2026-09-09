"use client";

import { useState } from "react";
import Link from "next/link";
import { Sheet } from "@/components/ui/Sheet";
import { buscarHref, type BuscarParams } from "@/lib/utils/buscar-href";
import { cn } from "@/lib/utils/cn";
import { SORT_OPTIONS } from "./FilterFields";

// The compact "Relevancia ▾" trigger next to the result count (`openSort`/
// `sortLabel` in `docs/design-reference/Fudo App.dc.html`'s `isList`). Opens
// the same three-way sort dimension FilterFields already exposes as a
// `<select>` inside the filter sheet — this is just a faster, one-tap path
// to the same `sort` param, not a second source of truth for the option
// list.

export function SortMenu({ current }: { current: BuscarParams }) {
  const [open, setOpen] = useState(false);
  const activeLabel =
    SORT_OPTIONS.find((option) => option.value === current.sort)?.label ??
    SORT_OPTIONS[0].label;

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="flex flex-none items-center gap-1 border-0 bg-transparent p-0 text-[13px] font-semibold text-accent-light"
      >
        {activeLabel}
        <span aria-hidden className="material-symbols text-[16px]" style={{ fontVariationSettings: "'wght' 300" }}>
          expand_more
        </span>
      </button>

      <Sheet open={open} onClose={() => setOpen(false)} title="Ordenar por">
        <div className="flex flex-col gap-1.5">
          {SORT_OPTIONS.map((option) => {
            const active = option.value === current.sort;
            return (
              <Link
                key={option.value}
                href={buscarHref(current, { sort: option.value || null })}
                scroll={false}
                onClick={() => setOpen(false)}
                aria-pressed={active}
                className={cn(
                  "flex items-center justify-between rounded-xl border px-4 py-3 text-[13.5px] font-semibold transition-colors",
                  active
                    ? "border-accent/35 bg-accent-soft text-accent-light"
                    : "border-border bg-surface text-foreground",
                )}
              >
                {option.label}
                {active ? (
                  <span aria-hidden className="material-symbols text-[18px]">
                    check
                  </span>
                ) : null}
              </Link>
            );
          })}
        </div>
      </Sheet>
    </>
  );
}
