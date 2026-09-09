"use client";

import Link from "next/link";
import { cn } from "@/lib/utils/cn";
import type { RewardEntry, RewardStatus } from "@/lib/types";

const STATUS_LABEL: Record<RewardStatus, string> = {
  permanent: "Beneficio permanente",
  ready: "Disponible",
  upcoming: "Próxima",
};

const STATUS_BADGE_CLASS: Record<RewardStatus, string> = {
  permanent: "bg-success-soft text-success",
  ready: "bg-success-soft text-success",
  upcoming: "bg-accent-soft text-accent",
};

function RewardRow({ entry }: { entry: RewardEntry }) {
  const { merchant, rule, status, visitsRemaining } = entry;

  return (
    <Link
      href={`/restaurantes/${merchant.id}`}
      className="flex items-center gap-3 rounded-[18px] border border-border bg-surface p-3.5 shadow-[inset_0_1px_0_var(--highlight)] transition-colors hover:border-accent/50"
    >
      <span className="flex h-10 w-10 flex-none items-center justify-center rounded-[13px] bg-accent-soft">
        <span aria-hidden className="material-symbols text-[20px] text-accent">
          redeem
        </span>
      </span>

      <div className="min-w-0 flex-1">
        <p className="truncate text-[13.5px] font-semibold text-foreground">
          {rule.reward_description}
        </p>
        <p className="truncate text-[12px] text-foreground-faint">
          {merchant.name}
          {status === "upcoming" && visitsRemaining
            ? ` · ${visitsRemaining === 1 ? "falta 1 visita" : `faltan ${visitsRemaining} visitas`}`
            : null}
        </p>
      </div>

      <span
        className={cn(
          "flex-none rounded-full px-2.5 py-1 text-[11px] font-bold",
          STATUS_BADGE_CLASS[status],
        )}
      >
        {STATUS_LABEL[status]}
      </span>
    </Link>
  );
}

export interface RewardsSectionProps {
  entries: RewardEntry[];
}

/**
 * "Recompensas" — every loyalty reward the consumer has already earned
 * (ready to redeem, or a merchant's permanent perk) plus the single next
 * reward pending per visited merchant. Distinct from VisitHistoryList (raw
 * visit counts/progress): this section is about the payoff itself, so a
 * reward earned at a merchant with few total visits can still outrank one
 * still far away at a merchant visited more — sorted with earned rewards
 * first, matching what a consumer actually wants to see and act on.
 */
export function RewardsSection({ entries }: RewardsSectionProps) {
  const sorted = [...entries].sort((a, b) => {
    const rank: Record<RewardStatus, number> = { permanent: 0, ready: 0, upcoming: 1 };
    return rank[a.status] - rank[b.status];
  });

  return (
    <section className="flex flex-col gap-3">
      <h2 className="text-[11px] font-bold uppercase tracking-[0.1em] text-foreground-faint">
        Recompensas
      </h2>

      {sorted.length === 0 ? (
        <div className="flex flex-col items-center gap-2.5 rounded-card border border-border bg-surface px-5 py-11 text-center">
          <span aria-hidden className="material-symbols text-[30px] text-foreground-faint">
            redeem
          </span>
          <p className="max-w-[230px] text-[14px] leading-relaxed text-foreground-muted">
            Sumá visitas en tus lugares favoritos para desbloquear recompensas.
          </p>
        </div>
      ) : (
        <div className="flex flex-col gap-2.5">
          {sorted.map((entry) => (
            <RewardRow key={`${entry.merchant.id}-${entry.rule.id}`} entry={entry} />
          ))}
        </div>
      )}
    </section>
  );
}
