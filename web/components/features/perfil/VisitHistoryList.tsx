"use client";

import Link from "next/link";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { MERCHANT_TYPE_BADGE } from "@/lib/mock/merchants";
import { cn } from "@/lib/utils/cn";
import type { VisitHistoryEntry } from "@/lib/mock/visit-history";

/** One visited-restaurant row's loyalty "stamps" — filled dots for visits
 * already made, hollow for the rest, out of that merchant's next reward
 * threshold. Mirrors `stamps()` in the design reference (`v.stamps`, capped
 * to a `LADDER_LENGTH`-ranged rule) — capped at 8 dots here so a merchant
 * with a far-off ladder step (e.g. 10 visits) doesn't render an oddly long
 * row on phone widths. Filled dots are `bg-accent` (orange), matching the
 * design's own `this.stamps(p, "#FF5023")` call for this exact list — the
 * only call site of `stamps()` in the reference, and it explicitly passes
 * orange, not the green `stamps()` defaults to elsewhere. */
function VisitStamps({ visits, target }: { visits: number; target: number }) {
  const dots = Math.min(target, 8);
  return (
    <div className="flex gap-1 pt-1.5" aria-hidden>
      {Array.from({ length: dots }, (_, index) => (
        <span
          key={index}
          className={cn(
            "h-2.5 w-2.5 rounded-full border",
            index < visits
              ? "border-transparent bg-accent"
              : "border-border bg-transparent",
          )}
        />
      ))}
    </div>
  );
}

function VisitRow({ entry }: { entry: VisitHistoryEntry }) {
  const { merchant, progress, tier, visitsLine } = entry;
  const typeBadge = MERCHANT_TYPE_BADGE[merchant.type];
  const nextStep = progress.steps.find((step) => step.isNext);

  return (
    <Link
      href={`/restaurantes/${merchant.id}`}
      className="flex items-center gap-3 rounded-[18px] border border-border bg-surface p-2.5 shadow-[inset_0_1px_0_var(--highlight)] transition-colors hover:border-accent/50"
    >
      <div className="relative h-14 w-14 flex-none overflow-hidden rounded-[13px] bg-surface-2">
        {merchant.cover_image_url ? (
          // eslint-disable-next-line @next/next/no-img-element -- external mock photos, matches components/buscar/MerchantCard.tsx
          <img
            src={merchant.cover_image_url}
            alt={merchant.name}
            loading="lazy"
            className="h-full w-full object-cover"
          />
        ) : (
          <div
            className="material-symbols flex h-full w-full items-center justify-center text-2xl"
            style={{ color: typeBadge.color }}
          >
            {typeBadge.icon}
          </div>
        )}
      </div>

      <div className="min-w-0 flex-1">
        <p className="truncate font-heading text-[17px] font-bold text-foreground">
          {merchant.name}
        </p>
        <p className="truncate text-[12px] text-foreground-faint">{visitsLine}</p>
        {nextStep?.rule ? (
          <VisitStamps visits={progress.visits} target={nextStep.rule.visits_required} />
        ) : null}
      </div>

      <span className="flex-none rounded-full bg-accent-soft px-2.5 py-1 text-[11px] font-bold text-accent">
        {tier}
      </span>
    </Link>
  );
}

export interface VisitHistoryListProps {
  entries: VisitHistoryEntry[];
}

/**
 * "Lugares que visitaste" — one row per merchant with at least one mocked
 * visit, each showing the visit count, a loyalty-progress stamp row, and a
 * tier badge. Layout mirrors the design reference exactly: a single stacked
 * column on phone, an `auto-fit minmax(300px, 1fr)` grid on wide (see
 * `isProfile`/`pVisitas` in both dc.html references) — a real structural
 * difference, not a CSS-only reflow, so it's branched the same way
 * MerchantCard branches its `layout` prop rather than solved with one
 * responsive className.
 */
export function VisitHistoryList({ entries }: VisitHistoryListProps) {
  const isPhone = useIsPhoneViewport();

  return (
    <section className="flex flex-col gap-3">
      <h2 className="text-[11px] font-bold uppercase tracking-[0.1em] text-foreground-faint">
        Lugares que visitaste
      </h2>

      {entries.length === 0 ? (
        <div className="flex flex-col items-center gap-2.5 rounded-card border border-border bg-surface px-5 py-11 text-center">
          <span aria-hidden className="material-symbols text-[30px] text-foreground-faint">
            storefront
          </span>
          <p className="max-w-[230px] text-[14px] leading-relaxed text-foreground-muted">
            Escaneá el QR de un local para empezar a sumar visitas.
          </p>
        </div>
      ) : (
        <div
          className={cn(
            "flex flex-col gap-2.5",
            !isPhone && "grid grid-cols-[repeat(auto-fit,minmax(280px,1fr))] gap-3.5",
          )}
        >
          {entries.map((entry) => (
            <VisitRow key={entry.merchant.id} entry={entry} />
          ))}
        </div>
      )}
    </section>
  );
}
