import type { MerchantType } from "@/lib/types";
import { MERCHANT_TYPE_LABELS, TAG_LABELS } from "@/lib/mock/merchants";
import type { BuscarParams } from "@/lib/utils/buscar-href";

// Row/category model for the mobile filters sheet (PhoneFilterSheet) —
// mirrors `FCATS`/`FDEF` in `docs/design-reference/Fudo App.dc.html`, mapped
// onto this app's real `BuscarParams` dimensions instead of the reference's
// mock `f`/`fDraft` state. Every option's `value` of `""` means "no filter"
// (rendered as "Cualquiera", same as the reference's own default string) —
// kept out of the emitted URL by `buscarHref`, same convention every other
// /buscar control already uses.
//
// Deliberately 4 categories, not the reference's 5: "premios" is gated on a
// signed-in visitor with real loyalty data there, which this app doesn't
// have wired into /buscar — the task's reference screenshot itself only
// ever shows the 4 that ship here.

export type FilterCategoryKey = "basico" | "precio" | "platos" | "ubicacion";

export interface FilterCategoryDef {
  key: FilterCategoryKey;
  label: string;
  icon: string;
}

export const FILTER_CATEGORIES: FilterCategoryDef[] = [
  { key: "basico", label: "Básico", icon: "tune" },
  { key: "precio", label: "Precio", icon: "payments" },
  { key: "platos", label: "Platos", icon: "restaurant_menu" },
  { key: "ubicacion", label: "Ubicación", icon: "location_on" },
];

export interface FilterOptionDef {
  value: string;
  label: string;
}

export interface FilterRowDef {
  id: string;
  cat: FilterCategoryKey;
  icon: string;
  label: string;
  options: FilterOptionDef[];
  getValue: (draft: BuscarParams) => string;
  setValue: (draft: BuscarParams, value: string) => BuscarParams;
}

const SORT_OPTIONS: FilterOptionDef[] = [
  { value: "", label: "Relevancia" },
  { value: "distancia", label: "Más cercanos" },
  { value: "precio", label: "Precio: menor a mayor" },
];

const OPEN_OPTIONS: FilterOptionDef[] = [
  { value: "", label: "Cualquiera" },
  { value: "now", label: "Abierto ahora" },
];

const PRICE_OPTIONS: FilterOptionDef[] = [
  { value: "", label: "Cualquiera" },
  { value: "0-20000", label: "Hasta $20.000" },
  { value: "20000-40000", label: "$20.000 – $40.000" },
  { value: "40000-999999999", label: "Más de $40.000" },
];

const DISTANCE_OPTIONS: FilterOptionDef[] = [
  { value: "", label: "Cualquiera" },
  { value: "1", label: "Hasta 1 km" },
  { value: "3", label: "Hasta 3 km" },
  { value: "5", label: "Hasta 5 km" },
];

/** The dietary subset of TAG_LABELS — the "Apto para" row in the Platos tab
 * is a single-select convenience over the same `tags` param the AiChips row
 * already multi-selects (the design reference has this exact overlap too:
 * its own `dishDiet`/`diet` picker rows sit alongside the `aiChips` pill
 * row). Picking here replaces only these three tags in `current.tags`,
 * leaving any other active tag (e.g. "economico") untouched. */
const DIET_TAG_KEYS = ["vegano", "sin_tacc", "picante"] as const;

function dietOptions(): FilterOptionDef[] {
  return [
    { value: "", label: "Cualquiera" },
    ...DIET_TAG_KEYS.map((tag) => ({ value: tag, label: TAG_LABELS[tag] })),
  ];
}

function simpleRow(
  id: string,
  cat: FilterCategoryKey,
  icon: string,
  label: string,
  paramKey: "sort" | "type" | "open" | "price" | "hood" | "dist",
  options: FilterOptionDef[],
): FilterRowDef {
  return {
    id,
    cat,
    icon,
    label,
    options,
    getValue: (draft) => draft[paramKey],
    setValue: (draft, value) => ({ ...draft, [paramKey]: value }),
  };
}

/**
 * Builds the row list for a given draft — `type` and `hood` need the
 * page's real available-values lists, so this is a function of props
 * rather than a static export.
 */
export function buildFilterRows(
  availableTypes: MerchantType[],
  availableHoods: string[],
): Record<FilterCategoryKey, FilterRowDef[]> {
  const typeOptions: FilterOptionDef[] = [
    { value: "", label: "Cualquiera" },
    ...availableTypes.map((type) => ({ value: type, label: MERCHANT_TYPE_LABELS[type] })),
  ];

  const hoodOptions: FilterOptionDef[] = [
    { value: "", label: "Cualquiera" },
    ...availableHoods.map((hood) => ({ value: hood, label: hood })),
  ];

  const dietRow: FilterRowDef = {
    id: "diet",
    cat: "platos",
    icon: "eco",
    label: "Apto para",
    options: dietOptions(),
    getValue: (draft) =>
      draft.tags
        .split(",")
        .find((tag): tag is (typeof DIET_TAG_KEYS)[number] =>
          (DIET_TAG_KEYS as readonly string[]).includes(tag),
        ) ?? "",
    setValue: (draft, value) => {
      const rest = draft.tags
        .split(",")
        .filter(Boolean)
        .filter((tag) => !(DIET_TAG_KEYS as readonly string[]).includes(tag));
      const next = value ? [...rest, value] : rest;
      return { ...draft, tags: next.join(",") };
    },
  };

  return {
    basico: [
      simpleRow("sort", "basico", "swap_vert", "Ordenar por", "sort", SORT_OPTIONS),
      simpleRow("type", "basico", "storefront", "Tipo de local", "type", typeOptions),
      simpleRow("open", "basico", "schedule", "Disponibilidad", "open", OPEN_OPTIONS),
    ],
    precio: [
      simpleRow("price", "precio", "payments", "Precio promedio", "price", PRICE_OPTIONS),
    ],
    platos: [dietRow],
    ubicacion: [
      ...(availableHoods.length > 0
        ? [simpleRow("hood", "ubicacion", "location_city", "Barrio", "hood", hoodOptions)]
        : []),
      simpleRow("dist", "ubicacion", "near_me", "Distancia", "dist", DISTANCE_OPTIONS),
    ],
  };
}

/** Clears every filter dimension the sheet controls, same set the
 * pre-existing "Limpiar filtros" link (FilterSidebar) clears — `sort` is
 * left untouched, same rationale as `countActiveFilters`'s doc comment:
 * it's a display choice, not a filter. */
export function clearedDraft(draft: BuscarParams): BuscarParams {
  return {
    ...draft,
    type: "",
    tags: "",
    price: "",
    hood: "",
    dist: "",
    open: "",
    hideVisited: "",
  };
}
