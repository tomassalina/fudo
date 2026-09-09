"use client";

import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { useSession } from "@/lib/session/use-session";
import type { DishSearchResult, Merchant, MerchantType } from "@/lib/types";
import type { BuscarParams } from "@/lib/utils/buscar-href";
import { SearchBar } from "./SearchBar";
import { AiChips } from "./AiChips";
import { ResultModeToggle, type ResultMode } from "./ResultModeToggle";
import { FilterSidebar } from "./FilterSidebar";
import { PhoneFilterSheet } from "./PhoneFilterSheet";
import { SearchResultsGrid } from "./SearchResultsGrid";
import { MapToggleSection } from "./MapToggleSection";

export interface BuscarViewProps {
  current: BuscarParams;
  query: string;
  activeType: MerchantType | null;
  activeTags: string[];
  availableTypes: MerchantType[];
  availableTags: string[];
  availableHoods: string[];
  mode: ResultMode;
  merchants: Merchant[];
  dishes: DishSearchResult[];
  countLabel: string;
  emptyTitle: string;
  clearHref: string;
}

/**
 * The phone/wide structural switch for the whole /buscar interactive shell —
 * same pattern as `AppNav` (see components/layout/nav/AppNav.tsx):
 * `useIsPhoneViewport()` picks genuinely different structure (a sticky
 * in-flow sidebar vs. a bottom sheet trigger, a single-column list vs. a
 * two-column grid), not a CSS-only `hidden md:flex` swap. Data (merchants,
 * dishes, filter option lists) is fetched server-side in app/buscar/page.tsx
 * and passed in as props — this component only owns view/interaction state
 * (which sheet is open, how much of the list is revealed, whether the map is
 * showing).
 */
export function BuscarView({
  current,
  query,
  activeType,
  activeTags,
  availableTypes,
  availableTags,
  availableHoods,
  mode,
  merchants,
  dishes,
  countLabel,
  emptyTitle,
  clearHref,
}: BuscarViewProps) {
  const isPhone = useIsPhoneViewport();
  const { isAuthenticated } = useSession();

  const filterFieldsProps = {
    current,
    activeType,
    availableTypes,
    availableHoods,
    isAuthenticated,
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center gap-2.5">
        <div className="min-w-0 flex-1">
          <SearchBar
            defaultValue={query}
            placeholder={
              isPhone ? undefined : "Buscar por nombre de local, plato, tipo o barrio"
            }
          />
        </div>
        {isPhone ? <PhoneFilterSheet {...filterFieldsProps} /> : null}
      </div>

      <AiChips current={current} activeTags={activeTags} availableTags={availableTags} />

      <div className="flex flex-wrap items-center gap-3">
        <ResultModeToggle current={current} mode={mode} />
        <span className="text-[13px] text-foreground-muted">{countLabel}</span>
      </div>

      <div
        className="grid items-start gap-6"
        style={
          isPhone
            ? undefined
            : { gridTemplateColumns: "minmax(220px,280px) minmax(0,1fr)" }
        }
      >
        {!isPhone ? <FilterSidebar {...filterFieldsProps} /> : null}

        <div className="flex min-w-0 flex-col gap-4">
          {mode === "lugares" ? <MapToggleSection merchants={merchants} /> : null}
          <SearchResultsGrid
            // Remounts (resetting the infinite-scroll reveal window) on any
            // filter/query change instead of patching state via an effect —
            // see the component's own doc comment.
            key={JSON.stringify(current)}
            mode={mode}
            merchants={merchants}
            dishes={dishes}
            emptyTitle={emptyTitle}
            clearHref={clearHref}
          />
        </div>
      </div>
    </div>
  );
}
