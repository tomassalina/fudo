import Link from "next/link";
import { buscarHref, type BuscarParams } from "@/lib/utils/buscar-href";
import { cn } from "@/lib/utils/cn";

/** `resModes` in both design references: a two-way pill switch between
 * merchant results ("Lugares") and dish results ("Platos"). Plain `<Link>`s
 * — a mode switch is just a URL change, no client state needed. */
export type ResultMode = "lugares" | "platos";

const MODES: { key: ResultMode; label: string; icon: string }[] = [
  { key: "lugares", label: "Lugares", icon: "storefront" },
  { key: "platos", label: "Platos", icon: "restaurant_menu" },
];

export function ResultModeToggle({
  current,
  mode,
  fullWidth = false,
}: {
  current: BuscarParams;
  mode: ResultMode;
  /** Phone layout (`isList` in the design reference) stretches both segments
   * to fill the bar edge-to-edge; wide keeps the original compact,
   * left-aligned pill. */
  fullWidth?: boolean;
}) {
  return (
    <div
      className={cn(
        "flex gap-1 rounded-full border border-border bg-surface p-1",
        fullWidth ? "w-full" : "flex-none",
      )}
    >
      {MODES.map((m) => {
        const active = mode === m.key;
        return (
          <Link
            key={m.key}
            href={buscarHref(current, { mode: m.key === "lugares" ? null : m.key })}
            scroll={false}
            aria-pressed={active}
            className={cn(
              "flex items-center justify-center gap-1.5 rounded-full py-2.5 text-[13px] font-semibold transition-colors duration-200",
              fullWidth ? "flex-1" : "px-4",
              active
                ? "bg-gradient-to-b from-cta-from to-cta-to text-white"
                : "text-foreground-faint hover:text-foreground",
            )}
          >
            <span aria-hidden className="material-symbols text-[17px]">
              {m.icon}
            </span>
            {m.label}
          </Link>
        );
      })}
    </div>
  );
}
