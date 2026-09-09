"use client";

// Home hero: headline + the AI search card, straight out of the design
// reference's `isHome` view (docs/design-reference/Fudo App.dc.html for
// phone, docs/design-reference/Fudo Customers.dc.html for wide). This is the
// one client island the home page needs — the typewriter animation runs on
// an interval, and the type-filter chip and submit both need interactivity —
// so only this sub-component is a client component, not the whole page.
//
// The typewriter overlay (`typed` + the blinking `fudoCaret` span) mirrors
// the reference's own `tick()` state machine (Fudo App.dc.html): type a
// character every 58ms, pause 1600ms at the full phrase, delete every 26ms,
// pause 260ms once empty, then move to the next phrase in SEARCH_EXAMPLES.

import { useEffect, useRef, useState } from "react";
import type { FormEvent } from "react";
import { useRouter } from "next/navigation";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { SEARCH_EXAMPLES } from "@/lib/mock/search";
import { MERCHANT_TYPE_LABELS, MERCHANT_TYPES_IN_USE } from "@/lib/mock/merchants";
import type { MerchantType } from "@/lib/types";
import { Button } from "@/components/ui/Button";
import { Sheet } from "@/components/ui/Sheet";
import { cn } from "@/lib/utils/cn";

const ANY_TYPE_LABEL = "Cualquiera";

/**
 * The home hero's type filter, in the same taxonomy `/buscar` already uses
 * (MERCHANT_TYPE_LABELS) instead of re-typing the design's own `HOME_TYPES`
 * copy — keeps one vocabulary for "type of place" across the app rather than
 * two slightly different wordings (the reference says "Cafetería", the rest
 * of this app says "Café").
 *
 * The option list itself comes from MERCHANT_TYPES_IN_USE — the same source
 * of truth `/buscar`'s own `parseType` uses (app/buscar/page.tsx) — instead
 * of every label in MERCHANT_TYPE_LABELS. That keeps Home from ever offering
 * a type with zero merchants behind it: picking one here and submitting
 * always lands on a type `/buscar` also recognizes as valid.
 */
const TYPE_OPTIONS: Array<{ value: MerchantType | null; label: string }> = [
  { value: null, label: ANY_TYPE_LABEL },
  ...MERCHANT_TYPES_IN_USE.map((type) => ({
    value: type,
    label: MERCHANT_TYPE_LABELS[type],
  })),
];

const TYPE_ICON = "storefront";

export function HeroSearch() {
  const router = useRouter();
  const isPhone = useIsPhoneViewport();

  const [query, setQuery] = useState("");
  const [typed, setTyped] = useState("");
  const [selectedType, setSelectedType] = useState<MerchantType | null>(null);
  const [typeSheetOpen, setTypeSheetOpen] = useState(false);

  // Typewriter state lives in refs, not state — it advances every 26-1600ms
  // and only `typed` needs to trigger a re-render.
  const phraseIndex = useRef(0);
  const charCount = useRef(0);
  const isDeleting = useRef(false);

  useEffect(() => {
    let timeoutId: ReturnType<typeof setTimeout>;

    const tick = () => {
      const phrase = SEARCH_EXAMPLES[phraseIndex.current % SEARCH_EXAMPLES.length];
      let wait = isDeleting.current ? 26 : 58;

      if (!isDeleting.current) {
        charCount.current += 1;
        setTyped(phrase.slice(0, charCount.current));
        if (charCount.current >= phrase.length) {
          isDeleting.current = true;
          wait = 1600;
        }
      } else {
        charCount.current -= 1;
        setTyped(phrase.slice(0, Math.max(0, charCount.current)));
        if (charCount.current <= 0) {
          isDeleting.current = false;
          phraseIndex.current += 1;
          wait = 260;
        }
      }

      timeoutId = setTimeout(tick, wait);
    };

    tick();
    return () => clearTimeout(timeoutId);
  }, []);

  const selectedOption =
    TYPE_OPTIONS.find((option) => option.value === selectedType) ?? TYPE_OPTIONS[0];

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const fallback = SEARCH_EXAMPLES[phraseIndex.current % SEARCH_EXAMPLES.length];
    const finalQuery = query.trim() || fallback;

    const params = new URLSearchParams({ q: finalQuery });
    if (selectedOption.value) {
      params.set("type", selectedOption.value);
    }
    router.push(`/buscar?${params.toString()}`);
  }

  return (
    <div
      className={cn(
        "flex flex-col",
        isPhone ? "items-start text-left" : "items-center text-center",
      )}
    >
      {isPhone ? (
        <h1 className="m-0 font-heading text-hero-fluid-phone font-black tracking-tight text-foreground text-balance">
          Encontrá dónde comer.
          <br />
          <em className="italic text-accent">Ganá descuentos</em> por
          cada visita.
        </h1>
      ) : (
        // Wide reproduces the reference's two separate <h1> elements
        // (docs/design-reference/Fudo Customers.dc.html) with a forced line
        // break and a 10px gap between them, instead of one <h1> that
        // depends on the text wrapping on its own.
        <>
          <h1 className="m-0 font-heading text-hero-fluid font-black tracking-tight text-foreground text-balance">
            Encontrá dónde comer.
          </h1>
          <h1
            className="m-0 font-heading text-hero-fluid font-black tracking-tight text-foreground text-balance"
            style={{ marginTop: "10px" }}
          >
            <em className="italic text-accent">Ganá descuentos</em> por
            cada visita.
          </h1>
        </>
      )}

      <form
        onSubmit={handleSubmit}
        className={cn(
          "relative w-full",
          isPhone ? "mt-7" : "mt-10 max-w-[600px]",
        )}
      >
        <div
          className={cn(
            "relative rounded-hero border border-border bg-surface shadow-hero",
            isPhone ? "px-[18px] pb-3.5 pt-5" : "px-6.5 pb-5 pt-6.5",
          )}
        >
          <span className="absolute inset-x-6 -top-px h-px bg-gradient-to-r from-transparent via-accent/55 to-transparent" />

          <div className="relative min-h-[46px]">
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              aria-label="Buscar restaurantes, bares o cafés"
              className={cn(
                "relative z-[2] w-full bg-transparent text-left leading-[1.35] text-foreground outline-none",
                isPhone ? "text-[17px]" : "text-[21px]",
              )}
            />
            {query.length === 0 ? (
              <div
                aria-hidden
                className={cn(
                  "pointer-events-none absolute inset-x-0 top-0 z-[1] text-left leading-[1.35] text-foreground-muted",
                  isPhone ? "text-[17px]" : "text-[21px]",
                )}
              >
                {typed}
                <span className="animate-fudo-caret text-accent">|</span>
              </div>
            ) : null}
          </div>

          <div className="flex items-center justify-between pt-3.5">
            <button
              type="button"
              onClick={() => setTypeSheetOpen(true)}
              className="flex items-center gap-1.5 rounded-full bg-surface-2 px-3.5 py-2 font-sans"
            >
              <span className="material-symbols text-[17px] text-accent">
                {TYPE_ICON}
              </span>
              <span className="text-[13.5px] font-semibold text-foreground">
                {selectedOption.label}
              </span>
              <span className="material-symbols text-[16px] text-foreground-faint">
                expand_more
              </span>
            </button>

            {isPhone ? (
              <Button type="submit" variant="primary" size="icon" aria-label="Buscar">
                <span className="material-symbols text-[21px] text-white">
                  arrow_forward
                </span>
              </Button>
            ) : (
              <Button type="submit" variant="primary" size="lg">
                <span className="material-symbols text-[19px] text-white">
                  auto_awesome
                </span>
                <span className="text-[15px] font-semibold text-white">
                  Buscar con IA
                </span>
              </Button>
            )}
          </div>
        </div>
      </form>

      <Sheet
        open={typeSheetOpen}
        onClose={() => setTypeSheetOpen(false)}
        title="Tipo de lugar"
        wideVariant="modal"
      >
        <div className="flex flex-col gap-2.5">
          {TYPE_OPTIONS.map((option) => {
            const isSelected = option.value === selectedOption.value;
            return (
              <button
                key={option.label}
                type="button"
                onClick={() => {
                  setSelectedType(option.value);
                  setTypeSheetOpen(false);
                }}
                className={cn(
                  "flex items-center justify-between gap-3 rounded-2xl border px-4 py-4 text-left font-sans transition-colors duration-150",
                  isSelected
                    ? "border-accent/35 bg-accent-soft"
                    : "border-border bg-surface hover:border-accent/50",
                )}
              >
                <span className="text-[14.5px] text-foreground">{option.label}</span>
                {isSelected ? (
                  <span className="flex h-[22px] w-[22px] flex-none items-center justify-center rounded-full bg-accent">
                    <span className="material-symbols text-[15px] text-white">
                      check
                    </span>
                  </span>
                ) : null}
              </button>
            );
          })}
        </div>
      </Sheet>
    </div>
  );
}
