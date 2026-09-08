"use client";

import { useEffect, useState } from "react";
import { SEARCH_EXAMPLES } from "@/lib/mock/search";

/**
 * The only client island on the Buscar page: rotates the input's placeholder
 * through example queries. The form itself is a plain GET form, so search
 * works even without JS — this just adds the cosmetic rotation on top.
 */
export function SearchBar({ defaultValue }: { defaultValue: string }) {
  const [exampleIndex, setExampleIndex] = useState(0);

  useEffect(() => {
    const id = setInterval(() => {
      setExampleIndex((current) => (current + 1) % SEARCH_EXAMPLES.length);
    }, 3000);

    return () => clearInterval(id);
  }, []);

  return (
    <form action="/buscar" method="GET" className="w-full">
      <div className="relative flex items-center gap-2 rounded-[26px] border border-border bg-surface px-5 py-4 shadow-lg shadow-black/20">
        <input
          type="text"
          name="q"
          defaultValue={defaultValue}
          placeholder={SEARCH_EXAMPLES[exampleIndex]}
          aria-label="Buscar restaurantes, bares o cafés"
          className="min-w-0 flex-1 bg-transparent text-[17px] text-foreground outline-none placeholder:text-foreground-faint"
        />
        <button
          type="submit"
          aria-label="Buscar"
          className="flex h-11 w-11 flex-none items-center justify-center rounded-full bg-gradient-to-b from-[#FF6337] to-[#E8431A] text-white shadow-md shadow-accent/30 transition-transform hover:scale-105 active:scale-95"
        >
          <span aria-hidden className="text-lg leading-none">
            →
          </span>
        </button>
      </div>
    </form>
  );
}
