import type { MerchantType } from "@/lib/types";
import { MERCHANT_TYPE_LABELS, TAG_LABELS } from "@/lib/mock/merchants";
import type { BuscarParams } from "@/lib/utils/buscar-href";
import { PRICE_BANDS } from "@/lib/utils/price-bands";

// Row/category model for the /buscar filters — shared, unmodified, by both
// PhoneFilterSheet (bottom sheet chrome) and FilterSidebar (always-visible
// wide-layout column, `docs/design-reference/Fudo Customers.dc.html`'s
// isList branch), per the explicit instruction to keep one filter
// state/data model and only let chrome differ between the two surfaces.
// Mirrors `FCATS`/`FDEF` in `docs/design-reference/Fudo App.dc.html`, mapped
// onto this app's real `BuscarParams` dimensions instead of the reference's
// mock `f`/`fDraft` state. Every option's `value` of `""` means "no filter"
// (rendered as "Cualquiera", same as the reference's own default string) —
// kept out of the emitted URL by `buscarHref`, same convention every other
// /buscar control already uses.
//
// 5 categories, matching the reference's own count: "premios" filters by
// `merchant.rewardTeaser` (see lib/types' doc comment on that field) — a
// UI-only derived value, same honest "no real backend column yet" situation
// `hideVisited` and `price` are already in (see their comments in
// app/buscar/page.tsx). It's a real, working filter today against
// MOCK_MERCHANTS; once real-API mode is active it naturally returns zero
// matches (every real merchant's `rewardTeaser` parses to `undefined` — see
// lib/api/merchants.ts) until the backend grows a loyalty_rules join for
// this UI to read instead of deriving it — nothing here needs to change
// when that lands, since the filter already reads the shared `Merchant`
// field, not a mock-only shortcut.

export type FilterCategoryKey =
  | "basico"
  | "precio"
  | "platos"
  | "ubicacion"
  | "premios";

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
  { key: "premios", label: "Premios", icon: "redeem" },
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

// Options derived from the shared band definitions (lib/utils/price-bands.ts)
// instead of a second hardcoded copy of the same three thresholds — that
// file is also where the home hero's AI search resolver maps Gemini's point
// price estimate onto one of these same bands (see
// lib/search/resolve-ai-search.ts), so there's exactly one source of truth
// for what a "price band" is in this app.
const PRICE_OPTIONS: FilterOptionDef[] = [
  { value: "", label: "Cualquiera" },
  ...PRICE_BANDS.map(({ value, label }) => ({ value, label })),
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
const DIET_TAG_KEYS = ["vegano", "sin_tacc", "picante", "vegetariano"] as const;

function dietOptions(): FilterOptionDef[] {
  return [
    { value: "", label: "Cualquiera" },
    ...DIET_TAG_KEYS.map((tag) => ({ value: tag, label: TAG_LABELS[tag] })),
  ];
}

const REWARD_OPTIONS: FilterOptionDef[] = [
  { value: "", label: "Cualquiera" },
  { value: "1", label: "Con premio por visitas" },
];

function simpleRow(
  id: string,
  cat: FilterCategoryKey,
  icon: string,
  label: string,
  paramKey: "sort" | "type" | "open" | "price" | "hood" | "dist" | "reward",
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
    premios: [
      simpleRow("reward", "premios", "redeem", "Premio por visitas", "reward", REWARD_OPTIONS),
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
    reward: "",
  };
}
