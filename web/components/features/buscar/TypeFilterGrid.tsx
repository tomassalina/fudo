import Link from "next/link";
import type { MerchantType } from "@/lib/types";
import { MERCHANT_TYPE_BADGE, MERCHANT_TYPE_LABELS } from "@/lib/mock/merchants";
import { buscarHref, type BuscarParams } from "@/lib/utils/buscar-href";
import { cn } from "@/lib/utils/cn";

// Merchant-type filter as an icon grid — `filterCats` in both design
// references (Fudo App.dc.html's isList sheet, Fudo Customers.dc.html's
// sticky sidebar): single-select, each button toggles itself off when
// already active. Deliberately plain `<Link>`s (server-safe, works without
// JS) instead of a client onClick, same rationale as the component this
// replaced (components/buscar/FilterChips.tsx, now split into this file
// plus AiChips.tsx to match the design's actual grouping: type is its own
// icon grid, tags/attributes are the separate "AI chips" pill row).

interface TypeFilterGridProps {
  current: BuscarParams;
  activeType: MerchantType | null;
  availableTypes: MerchantType[];
}

export function TypeFilterGrid({
  current,
  activeType,
  availableTypes,
}: TypeFilterGridProps) {
  if (availableTypes.length === 0) return null;

  return (
    <div className="grid grid-cols-[repeat(auto-fill,minmax(78px,1fr))] gap-2">
      {availableTypes.map((type) => {
        const active = activeType === type;
        const badge = MERCHANT_TYPE_BADGE[type];
        return (
          <Link
            key={type}
            href={buscarHref(current, { type: active ? null : type })}
            scroll={false}
            aria-pressed={active}
            className={cn(
              "flex flex-col items-center gap-1 rounded-xl border px-2 py-2.5 text-center transition-colors duration-200",
              active
                ? "border-accent/35 bg-accent-soft text-accent-light"
                : "border-border bg-surface text-foreground-faint hover:border-accent/50 hover:text-foreground",
            )}
          >
            <span
              aria-hidden
              className="material-symbols text-[19px]"
              style={{ color: active ? undefined : badge.color }}
            >
              {badge.icon}
            </span>
            <span className="truncate text-[12px] font-semibold">
              {MERCHANT_TYPE_LABELS[type]}
            </span>
          </Link>
        );
      })}
    </div>
  );
}
