"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { buscarHref, type BuscarParams } from "@/lib/utils/buscar-href";

/**
 * The compact results-page search bar — `isList`'s search row in both design
 * references (`docs/design-reference/Fudo App.dc.html`), not the big
 * rotating-placeholder hero search (that one lives on the home page's own
 * `HeroSearch.tsx`). Static placeholder, a search glyph on the left, and an
 * "x" to clear the field once it has text — no submit button: a form with a
 * single text field submits on Enter per the HTML living standard's implicit
 * submission rule.
 *
 * The `action`/`method="GET"` attributes stay on the `<form>` as a real
 * progressive-enhancement fallback (search still narrows results with JS
 * disabled — though a no-JS submit only ever sends `q`, since that's the
 * form's only field, dropping whatever other filters were active; a
 * pre-existing limitation of the plain-GET-form approach, not something this
 * component's JS layer regresses). With JS enabled, `onSubmit` intercepts the
 * submission (`preventDefault`) and does a same-route client navigation via
 * `buscarHref` instead — merging the new `q` on top of every other current
 * param (so active filters survive a search) and avoiding the full document
 * reload (and the resulting loss of in-page state, e.g. the map's pan/zoom)
 * a real GET form submission causes.
 */
export function SearchBar({
  defaultValue,
  placeholder = "Buscar por nombre, tipo o barrio",
  current,
}: {
  defaultValue: string;
  placeholder?: string;
  /** Every other current `/buscar` param, so submitting a search preserves
   * active filters instead of navigating to a bare `?q=...`. */
  current: BuscarParams;
}) {
  const [value, setValue] = useState(defaultValue);
  const router = useRouter();

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    // `push`, not `replace` — matches the rest of this page's "a deliberate
    // search/filter action gets its own back-button stop" convention
    // (PhoneFilterSheet/FilterSidebar's `router.push` on Aplicar, SortMenu's
    // plain `<Link>`), not the "silent background sync" `replace` convention
    // reserved for BuscarView's own geolocation-into-URL effect and the map
    // open/close `tab` toggle. A submitted search is exactly the kind of
    // explicit, content-changing action a visitor would expect Back to undo,
    // same as changing a filter.
    router.push(buscarHref(current, { q: value || null }));
  }

  return (
    <form action="/buscar" method="GET" className="w-full" onSubmit={handleSubmit}>
      <div className="flex min-w-0 items-center gap-2.5 rounded-full border border-border bg-surface px-[15px] py-[11px] shadow-[inset_0_1px_0_var(--highlight)]">
        <span
          aria-hidden
          className="material-symbols flex-none text-[18px] leading-none text-foreground-faint"
          style={{ fontVariationSettings: "'wght' 250" }}
        >
          search
        </span>
        <input
          type="text"
          name="q"
          value={value}
          onChange={(event) => setValue(event.target.value)}
          placeholder={placeholder}
          aria-label="Buscar por nombre, tipo o barrio"
          className="min-w-0 flex-1 bg-transparent text-[14px] text-foreground outline-none placeholder:text-foreground-faint"
        />
        {value ? (
          <button
            type="button"
            onClick={() => setValue("")}
            aria-label="Borrar búsqueda"
            className="flex flex-none items-center justify-center border-0 bg-transparent p-0"
          >
            <span
              aria-hidden
              className="material-symbols text-[18px] leading-none text-foreground-faint"
              style={{ fontVariationSettings: "'wght' 300" }}
            >
              close
            </span>
          </button>
        ) : null}
      </div>
    </form>
  );
}
