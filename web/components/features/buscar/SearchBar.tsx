"use client";

import { useState } from "react";

/**
 * The compact results-page search bar — `isList`'s search row in both design
 * references (`docs/design-reference/Fudo App.dc.html`), not the big
 * rotating-placeholder hero search (that one lives on the home page's own
 * `HeroSearch.tsx`). Static placeholder, a search glyph on the left, and an
 * "x" to clear the field once it has text — no submit button: a form with a
 * single text field submits on Enter per the HTML living standard's implicit
 * submission rule, so search still works with JS disabled (the clear button
 * is the only bit that needs it, same as the rest of this page's philosophy
 * — see BuscarView's doc comment).
 */
export function SearchBar({
  defaultValue,
  placeholder = "Buscar por nombre, tipo o barrio",
}: {
  defaultValue: string;
  placeholder?: string;
}) {
  const [value, setValue] = useState(defaultValue);

  return (
    <form action="/buscar" method="GET" className="w-full">
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
