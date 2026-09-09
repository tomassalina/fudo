"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { useLocation } from "@/lib/location/use-location";
import { useSession } from "@/lib/session/use-session";
import type { DishSearchResult, Merchant, MerchantType } from "@/lib/types";
import { buscarHref, type BuscarParams } from "@/lib/utils/buscar-href";
import { cn } from "@/lib/utils/cn";
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
  //
  // Derived directly from `current.tab` (same pattern as `mode` above, which
  // has no local state either) rather than mirrored into local `useState`.
  // BuscarView is intentionally never remounted across router.push/replace
  // navigations on /buscar (no `key` anywhere in its ancestor chain — that's
  // what keeps the Leaflet map instance and its pan/zoom alive across filter
  // changes), so a `useState` initializer here would only run once on first
  // mount and go stale on any later navigation that changes `current.tab`
  // without remounting — e.g. open the map (tab=map), then browser Back to
  // an earlier `tab`-less history entry: the URL says list view but stale
  // state would still read `true`. Deriving directly sidesteps that class of
  // bug entirely — `showMap` always matches whatever `current.tab` the
  // server most recently rendered with, on every render, no sync needed.
  const showMap = current.tab === "map";
  const showDesktopMapSplit = mode === "lugares" && showMap && !isPhone;
  const hidePhoneListWhileMapping = mode === "lugares" && showMap && isPhone;

  // Single toggle path for every "open/close the map" control (the phone
  // pill, desktop's "Ver mapa" button, DesktopMapSplit's "Ver lista" exit) —
  // mirrors the choice into `?tab=map` (cleared, not set to a literal
  // "list", when closing — see BuscarParams' own doc comment on `tab`), and
  // `showMap` above (derived straight from `current.tab`) picks it up on the
  // next render once the URL update lands — no local state to keep in sync.
  // `router.replace` (not `push`): opening/closing the map is a view toggle
  // on the same result set, not a new search — same rationale as the
  // geolocation-sync effect below, and deliberately NOT the `router.push`
  // convention PhoneFilterSheet/FilterSidebar's "Aplicar" and SortMenu use
  // for an actual filter/search change (see SearchBar's own doc comment for
  // the full push-vs-replace breakdown) — toggling the map open and shut a
  // few times while browsing shouldn't leave a trail of back-button stops.
  function handleToggleMap(next: boolean) {
    router.replace(buscarHref(current, { tab: next ? "map" : null }), {
      scroll: false,
    });
  }

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

  // Search bar (+ filter trigger on phone, and on desktop's map view — see
  // below) — per the design reference (docs/design-reference/Fudo
  // Customers.dc.html, the `isList` view) this lives INSIDE the grid's right
  // column, stacked above the results, not as a full-width header floating
  // above the [FilterSidebar | content] grid. Kept as its own JSX chunk
  // (rather than inlined twice) so the exact same chunk can be handed to
  // MapToggleSection as its floating `overlay` while the phone map is open,
  // AND to DesktopMapSplit as its own `mapOverlay` prop while the desktop
  // map view is open (below) — floating over the map column in both cases.
  // Went through a couple of live-feedback rounds landing on an in-flow row
  // instead for desktop, then back to floating (final call, this time
  // aligned to DesktopMapSplit's left-column header row — see MapPanel's
  // own `overlay` doc comment for that alignment contract). Mobile's
  // floating overlay was never touched by any of that back-and-forth.
  //
  // The filter TRIGGER (not the search input itself) only renders on phone
  // OR while the desktop map view is showing: FilterSidebar (the always
  // visible wide-layout filter column) is what desktop normally relies on,
  // but DesktopMapSplit replaces that whole [FilterSidebar | grid] pair —
  // filters need a way back in while it's active, same sheet-based trigger
  // phone already uses (PhoneFilterSheet works as plain modal UI regardless
  // of viewport, nothing phone-specific about its own rendering).
  const searchBar = (
    <div className="flex items-center gap-2.5">
      <div className="min-w-0 flex-1">
        <SearchBar
          defaultValue={query}
          placeholder={
            isPhone ? undefined : "Buscar por nombre de local, plato, tipo o barrio"
          }
          current={current}
        />
      </div>
      {isPhone || showDesktopMapSplit ? <PhoneFilterSheet {...filterFieldsProps} /> : null}
    </div>
  );

  // Same "float on top of the map instead of sitting in flow above it"
  // treatment for the phone-only mode toggle + AI chips row that normally
  // stacks right under the search bar — see MapToggleSection's `overlay` doc
  // comment for why this lives here (BuscarView) rather than inside that
  // component. Only ever built (and only ever handed to MapToggleSection)
  // while `hidePhoneListWhileMapping` is true; MapToggleSection itself is a
  // no-op on wide viewports and renders nothing while `showMap` is false, so
  // passing `undefined` the rest of the time keeps this cheap.
  // Map mode (phone): just the search bar + filter trigger float over the
  // map — no Lugares/Platos toggle, no diet-tag chips. Filtering by dish
  // doesn't make sense on a map of places, so both are deliberately omitted
  // here even though they render in normal list mode above.
  const mapOverlay = hidePhoneListWhileMapping ? <>{searchBar}</> : null;

  return (
    // Anchored to a real `100vh` calc, only while the desktop map view is
    // showing — NOT `flex-1`: `<main>`'s own ancestors (`body`) use
    // `min-h-full`, not a hard `height`, specifically so normal pages can
    // grow past one viewport and scroll. That means a `flex-1`/`h-full`
    // chain rooted here has no real ceiling to stop at — tried it, it
    // produced a page that grew to ~4000px instead of filling one screen
    // (confirmed live). `calc(100vh-101px)` is the one genuinely fixed
    // quantity available: WideNav's own `h-17` + its 1px border (69px,
    // confirmed against WideNav.tsx) plus `<main>`'s `pt-8` (32px) — both
    // real, non-viewport-dependent constants, not a guess. `-mb-28` cancels
    // out `<main>`'s own `pb-28` (mobile bottom-nav clearance, irrelevant on
    // desktop — see the identical `pb-28` doc comment in
    // components/features/home/HeroSection.tsx) for exactly this branch, so
    // the map genuinely reaches the real bottom of the viewport instead of
    // stopping ~112px short of it: negative margin overflows *into* that
    // trailing padding rather than being clipped by it (`<main>` has no
    // `overflow-hidden` of its own), while `<main>`'s own computed height
    // still comes out exactly right (pt-8 + (height-112) + pb-28 == height)
    // so this doesn't reintroduce page-level scroll either. Every other case
    // (normal list, phone) keeps sizing off content height exactly as
    // before.
    <div
      className={cn(
        "flex flex-col gap-4",
        showDesktopMapSplit && "h-[calc(100vh-101px)] -mb-28",
      )}
    >
      <div
        className={cn(
          "grid gap-7",
          // `items-stretch` (not `items-start`) specifically for the
          // desktop map split: it's the single item in this implicit grid
          // row, and with `items-start` a grid item never stretches to fill
          // a tall row — it just sizes to its own content and sits at the
          // top, which would starve DesktopMapSplit's `h-full` of any real
          // height to inherit (a `flex-1` row height on the container alone
          // isn't enough). Every other case keeps `items-start` — the normal
          // [FilterSidebar | grid] layout deliberately does NOT want its
          // columns force-stretched to match each other's height.
          showDesktopMapSplit ? "min-h-0 flex-1 items-stretch" : "items-start",
        )}
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
            onExit={() => handleToggleMap(false)}
            userLocation={coords}
            mapOverlay={searchBar}
          />
        ) : (
          <>
            {!isPhone ? <FilterSidebar {...filterFieldsProps} /> : null}

            <div className="flex min-w-0 flex-col gap-4">
              {/* List mode (map closed) keeps this in normal document flow
                  exactly as before. Map open on phone: this same content is
                  rendered instead as MapToggleSection's floating `overlay`
                  (`mapOverlay` above) — omitted here so it isn't rendered
                  twice. */}
              {hidePhoneListWhileMapping ? null : searchBar}

              {hidePhoneListWhileMapping ? null : isPhone ? (
                <>
                  <ResultModeToggle current={current} mode={mode} fullWidth />
                  <AiChips
                    current={current}
                    activeTags={activeTags}
                    availableTags={availableTags}
                  />
                </>
              ) : (
                // Desktop: a single row — mode toggle + result count on the
                // left, sort + "Ver mapa" on the right — matching the design
                // reference exactly ("N lugares · Relevancia ▾ · Ver mapa" as
                // one line, not the toggle/AI-chips/count-row stack phone
                // uses). No AI chips here: confirmed out of scope for the
                // desktop /buscar view — they still show on phone above.
                <div className="flex items-center justify-between gap-3">
                  <div className="flex items-center gap-3">
                    <ResultModeToggle current={current} mode={mode} />
                    <span className="text-[13px] text-foreground-muted">{countLabel}</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <SortMenu current={current} />
                    {mode === "lugares" ? (
                      // Desktop's own "Ver mapa" toggle — plain in-flow
                      // button (unlike the phone pill, no map-mode lock or
                      // full-screen layer to own; MapToggleSection is
                      // phone-only, see its doc comment).
                      <button
                        type="button"
                        onClick={() => handleToggleMap(true)}
                        className="flex w-fit items-center gap-1.5 rounded-full border border-border bg-surface px-4 py-2.5 text-[13px] font-semibold text-foreground transition-colors hover:border-accent/50"
                      >
                        <span aria-hidden className="material-symbols text-[17px]">
                          map
                        </span>
                        Ver mapa
                      </button>
                    ) : null}
                  </div>
                </div>
              )}

              {mode === "lugares" ? (
                <MapToggleSection
                  merchants={merchants}
                  showMap={showMap}
                  onToggle={handleToggleMap}
                  overlay={mapOverlay}
                  userLocation={coords}
                />
              ) : null}

              {hidePhoneListWhileMapping ? null : (
                <>
                  {isPhone ? (
                    <div className="flex items-baseline justify-between px-0.5">
                      <span className="text-[13px] text-foreground-muted">{countLabel}</span>
                      <SortMenu current={current} />
                    </div>
                  ) : null}

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
