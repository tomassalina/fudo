"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { useLocation } from "@/lib/location/use-location";
import { useSession } from "@/lib/session/use-session";
import type { DishSearchResult, Merchant, MerchantType } from "@/lib/types";
import { buscarHref, type BuscarParams } from "@/lib/utils/buscar-href";
import { SearchBar } from "./SearchBar";
import { AiChips } from "./AiChips";
import { ResultModeToggle, type ResultMode } from "./ResultModeToggle";
import { FilterSidebar } from "./FilterSidebar";
import { PhoneFilterSheet } from "./PhoneFilterSheet";
import { SearchResultsGrid } from "./SearchResultsGrid";
import { MapToggleSection } from "./MapToggleSection";
import { DesktopMapSplit } from "./DesktopMapSplit";
import { SortMenu } from "./SortMenu";

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
 * Rounded to 3 decimals (~110m) before it ever reaches the URL — enough
 * precision for the "closest neighborhood" use case (same "city-scale
 * accuracy" call use-location.ts's GEOLOCATION_OPTIONS makes), while not
 * putting the visitor's exact live position into a link that's plainly
 * visible and easy to copy/share.
 */
function toUrlCoordinate(value: number): string {
  return value.toFixed(3);
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
  const router = useRouter();
  const { coords } = useLocation();
  const latitude = coords?.latitude;
  const longitude = coords?.longitude;
  // Lifted out of MapToggleSection: on wide viewports this flag now decides
  // between two entirely different layouts below (sidebar+grid vs.
  // DesktopMapSplit's compact-list+big-map), not just whether one section's
  // own panel is visible — see MapToggleSection's doc comment.
  const [showMap, setShowMap] = useState(false);
  const showDesktopMapSplit = mode === "lugares" && showMap && !isPhone;
  const hidePhoneListWhileMapping = mode === "lugares" && showMap && isPhone;

  // The Server Component (app/buscar/page.tsx) has no access to the
  // browser's geolocation on its own, so once the visitor activates it via
  // the header's "Activar ubicación" pill (lib/location/use-location.ts),
  // this syncs it into the URL as `?lat=&lng=` — the page then reads those
  // from `searchParams` to compute each merchant's real distanceKm
  // server-side (see withDistances there), which "sort=distancia" and the
  // "dist" filter both depend on. `router.replace` (not `push`) so toggling
  // location on/off doesn't spam the back-button history, and the effect
  // only fires a navigation when the URL's current lat/lng actually
  // disagrees with the live value — otherwise every render would loop.
  useEffect(() => {
    if (latitude != null && longitude != null) {
      const lat = toUrlCoordinate(latitude);
      const lng = toUrlCoordinate(longitude);
      if (current.lat !== lat || current.lng !== lng) {
        router.replace(buscarHref(current, { lat, lng }), { scroll: false });
      }
    } else if (current.lat || current.lng) {
      router.replace(buscarHref(current, { lat: null, lng: null }), {
        scroll: false,
      });
    }
  }, [latitude, longitude, current, router]);

  const filterFieldsProps = {
    current,
    activeType,
    availableTypes,
    availableHoods,
    isAuthenticated,
  };

  // Search bar (+ phone filter trigger) / result-mode toggle / AI chips —
  // per the design reference (docs/design-reference/Fudo Customers.dc.html,
  // the `isList` view) these three live INSIDE the grid's right column,
  // stacked above the results, not as a full-width header floating above
  // the [FilterSidebar | content] grid. Kept as one JSX chunk (rather than
  // inlined twice) so it can also sit above DesktopMapSplit unchanged when
  // that view is active — DesktopMapSplit owns its own self-contained
  // layout and isn't part of this grid (see its doc comment).
  const searchAndControls = (
    <>
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

      <ResultModeToggle current={current} mode={mode} fullWidth={isPhone} />

      <AiChips current={current} activeTags={activeTags} availableTags={availableTags} />
    </>
  );

  return (
    <div className="flex flex-col gap-4">
      {showDesktopMapSplit ? searchAndControls : null}

      <div
        className="grid items-start gap-7"
        style={
          isPhone || showDesktopMapSplit
            ? undefined
            : { gridTemplateColumns: "minmax(220px,280px) minmax(0,1fr)" }
        }
      >
        {showDesktopMapSplit ? (
          // Desktop map view: replaces the [FilterSidebar | grid] pair
          // entirely instead of nesting a map into it — see
          // DesktopMapSplit's own doc comment for why (matches the design
          // reference: filters hidden, a compact list + a big always-visible
          // map instead).
          <DesktopMapSplit
            merchants={merchants}
            countLabel={countLabel}
            onExit={() => setShowMap(false)}
          />
        ) : (
          <>
            {!isPhone ? <FilterSidebar {...filterFieldsProps} /> : null}

            <div className="flex min-w-0 flex-col gap-4">
              {searchAndControls}

              {mode === "lugares" ? (
                <MapToggleSection
                  merchants={merchants}
                  showMap={showMap}
                  onToggle={setShowMap}
                />
              ) : null}

              {hidePhoneListWhileMapping ? null : (
                <>
                  <div className="flex items-baseline justify-between px-0.5">
                    <span className="text-[13px] text-foreground-muted">{countLabel}</span>
                    <div className="flex items-center gap-2">
                      {mode === "lugares" && !isPhone ? (
                        // Desktop's own "Ver mapa" toggle — plain in-flow
                        // button (unlike the phone pill, no map-mode lock or
                        // full-screen layer to own; MapToggleSection is
                        // phone-only, see its doc comment) sitting right next
                        // to SortMenu so this reads as one row — "N lugares
                        // encontrados · Relevancia ▾ · Ver mapa" — matching
                        // the design reference instead of its own line above.
                        <button
                          type="button"
                          onClick={() => setShowMap(true)}
                          className="flex w-fit items-center gap-1.5 rounded-full border border-border bg-surface px-4 py-2.5 text-[13px] font-semibold text-foreground transition-colors hover:border-accent/50"
                        >
                          <span aria-hidden className="material-symbols text-[17px]">
                            map
                          </span>
                          Ver mapa
                        </button>
                      ) : null}
                      <SortMenu current={current} />
                    </div>
                  </div>

                  <SearchResultsGrid
                    // Remounts (resetting the infinite-scroll reveal window) on any
                    // filter/query change instead of patching state via an effect —
                    // see the component's own doc comment. `lat`/`lng` are excluded
                    // (JSON.stringify drops `undefined`-valued keys) for the same
                    // reason countActiveFilters (lib/utils/buscar-href.ts) excludes
                    // them from the filter badge: they're position data synced
                    // automatically by the effect above, not a filter the visitor
                    // picked. Without this exclusion, activating geolocation
                    // mid-session — or any later lat/lng drift — would remount the
                    // grid and silently reset the visibleCount the visitor already
                    // revealed via infinite scroll.
                    key={JSON.stringify({ ...current, lat: undefined, lng: undefined })}
                    mode={mode}
                    merchants={merchants}
                    dishes={dishes}
                    emptyTitle={emptyTitle}
                    clearHref={clearHref}
                  />
                </>
              )}
            </div>
          </>
        )}
      </div>
    </div>
  );
}
