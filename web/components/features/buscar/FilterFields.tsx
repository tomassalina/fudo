"use client";

import { useRouter } from "next/navigation";
import type { MerchantType } from "@/lib/types";
import { buscarHref, type BuscarParams } from "@/lib/utils/buscar-href";
import { TypeFilterGrid } from "./TypeFilterGrid";

// The advanced filter rows from the sidebar/sheet (`filterRows` in both
// design references: price, neighborhood, distance, sort) plus the
// login-gated "ocultar visitados" toggle. The reference opens a picker
// sheet per row; this ships them as plain `<select>`s instead — same
// filter coverage, far less bespoke picker-UI surface, and still fully
// keyboard/screen-reader accessible. Client Component because a `<select>`
// needs `onChange` to navigate (no server-renderable equivalent to a
// GET-form submit-per-keystroke), unlike the plain `<Link>` chips.

export const PRICE_OPTIONS = [
  { value: "", label: "Cualquier precio" },
  { value: "0-20000", label: "Hasta $20.000" },
  { value: "20000-40000", label: "$20.000 – $40.000" },
  { value: "40000-999999999", label: "Más de $40.000" },
] as const;

export const DISTANCE_OPTIONS = [
  { value: "", label: "Cualquier distancia" },
  { value: "1", label: "Hasta 1 km" },
  { value: "3", label: "Hasta 3 km" },
  { value: "5", label: "Hasta 5 km" },
] as const;

export const SORT_OPTIONS = [
  { value: "", label: "Relevancia" },
  { value: "distancia", label: "Más cercanos" },
  { value: "precio", label: "Precio: menor a mayor" },
] as const;

const selectClass =
  "w-full rounded-xl border border-border bg-surface px-3 py-2.5 text-[13px] font-medium text-foreground outline-none transition-colors focus:border-accent/50";

interface FilterFieldsProps {
  current: BuscarParams;
  activeType: MerchantType | null;
  availableTypes: MerchantType[];
  availableHoods: string[];
  isAuthenticated: boolean;
}

export function FilterFields({
  current,
  activeType,
  availableTypes,
  availableHoods,
  isAuthenticated,
}: FilterFieldsProps) {
  const router = useRouter();

  function navigate(overrides: Partial<Record<keyof BuscarParams, string | null>>) {
    router.push(buscarHref(current, overrides));
  }

  return (
    <div className="flex flex-col gap-4">
      {isAuthenticated ? (
        <label className="flex items-center gap-2.5 rounded-xl border border-border bg-surface px-3 py-2.5 text-[13px] font-semibold text-foreground">
          <input
            type="checkbox"
            checked={current.hideVisited === "1"}
            onChange={(event) =>
              navigate({ hideVisited: event.target.checked ? "1" : null })
            }
            className="h-4 w-4 accent-accent"
          />
          <span aria-hidden className="material-symbols text-[17px] text-foreground-muted">
            visibility_off
          </span>
          Ocultar visitados
        </label>
      ) : null}

      <div>
        <p className="pb-2 text-[11px] font-bold uppercase tracking-widest text-foreground-faint">
          Tipo de lugar
        </p>
        <TypeFilterGrid
          current={current}
          activeType={activeType}
          availableTypes={availableTypes}
        />
      </div>

      <label className="flex flex-col gap-1.5 text-[12px] font-semibold text-foreground-muted">
        Precio
        <select
          className={selectClass}
          value={current.price}
          onChange={(event) => navigate({ price: event.target.value || null })}
        >
          {PRICE_OPTIONS.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
      </label>

      {availableHoods.length > 0 ? (
        <label className="flex flex-col gap-1.5 text-[12px] font-semibold text-foreground-muted">
          Barrio
          <select
            className={selectClass}
            value={current.hood}
            onChange={(event) => navigate({ hood: event.target.value || null })}
          >
            <option value="">Cualquier barrio</option>
            {availableHoods.map((hood) => (
              <option key={hood} value={hood}>
                {hood}
              </option>
            ))}
          </select>
        </label>
      ) : null}

      <label className="flex flex-col gap-1.5 text-[12px] font-semibold text-foreground-muted">
        Distancia
        <select
          className={selectClass}
          value={current.dist}
          onChange={(event) => navigate({ dist: event.target.value || null })}
        >
          {DISTANCE_OPTIONS.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
      </label>

      <label className="flex flex-col gap-1.5 text-[12px] font-semibold text-foreground-muted">
        Ordenar por
        <select
          className={selectClass}
          value={current.sort}
          onChange={(event) => navigate({ sort: event.target.value || null })}
        >
          {SORT_OPTIONS.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
      </label>
    </div>
  );
}
