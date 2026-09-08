import Link from "next/link";
import type { Merchant } from "@/lib/types";
import {
  MERCHANT_TYPE_BADGE,
  MERCHANT_TYPE_LABELS,
  TAG_LABELS,
} from "@/lib/mock/merchants";

function formatFromPrice(min: number) {
  return `desde $${min.toLocaleString("es-AR")}`;
}

export function MerchantCard({ merchant }: { merchant: Merchant }) {
  const visibleTags = merchant.tags.slice(0, 3);
  const typeBadge = MERCHANT_TYPE_BADGE[merchant.type];

  return (
    <article className="flex gap-3 rounded-[18px] border border-border bg-surface p-2.5 shadow-inner shadow-white/5 transition-colors hover:border-accent/50">
      <Link
        href={`/restaurantes/${merchant.id}`}
        className="relative h-[88px] w-[88px] flex-none overflow-hidden rounded-[13px] bg-surface-2"
      >
        {merchant.cover_image_url ? (
          // eslint-disable-next-line @next/next/no-img-element -- external mock photos, not worth Image config for this low-priority pass
          <img
            src={merchant.cover_image_url}
            alt={merchant.name}
            loading="lazy"
            className="h-full w-full object-cover"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center bg-surface-2 text-3xl">
            {typeBadge}
          </div>
        )}
        <span className="absolute bottom-1 left-1 flex h-6 w-6 items-center justify-center rounded-full bg-black/55 text-[13px] leading-none">
          {typeBadge}
        </span>
      </Link>

      <div className="flex min-w-0 flex-1 flex-col gap-1 pt-0.5">
        <Link href={`/restaurantes/${merchant.id}`} className="min-w-0">
          <h3 className="truncate font-heading text-lg font-bold text-foreground hover:text-accent-light">
            {merchant.name}
          </h3>
        </Link>
        <p className="truncate text-[12.5px] text-foreground-muted">
          {merchant.neighborhood} · {MERCHANT_TYPE_LABELS[merchant.type]}
        </p>
        {merchant.topDish ? (
          <p className="truncate text-[12.5px] text-foreground-faint">
            {merchant.topDish}
          </p>
        ) : null}

        <div className="flex flex-wrap items-center gap-2 pt-1">
          {merchant.price_per_person_min != null ? (
            <span className="rounded-full bg-accent-soft px-2.5 py-0.5 text-[12.5px] font-bold text-accent-light">
              {formatFromPrice(merchant.price_per_person_min)}
            </span>
          ) : null}
          <span className="text-[12.5px] text-foreground-faint">
            📍 {merchant.distanceKm.toLocaleString("es-AR")} km
          </span>
          {merchant.rewardTeaser ? (
            <span className="text-[12px] font-semibold text-success">
              🎁 {merchant.rewardTeaser}
            </span>
          ) : null}
        </div>

        {visibleTags.length > 0 ? (
          <div className="flex flex-wrap gap-1.5 pt-0.5">
            {visibleTags.map((tag) => (
              <span
                key={tag}
                className="rounded-full bg-success-soft px-2 py-0.5 text-[10px] font-bold text-success"
              >
                {TAG_LABELS[tag] ?? tag}
              </span>
            ))}
          </div>
        ) : null}

        <Link
          href={`/restaurantes/${merchant.id}`}
          className="pt-0.5 text-[12.5px] font-semibold text-accent hover:text-accent-light"
        >
          Ver más →
        </Link>
      </div>
    </article>
  );
}
