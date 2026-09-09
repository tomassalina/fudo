"use client";

import Link from "next/link";
import type { Merchant } from "@/lib/types";
import { useMerchantDistanceKm } from "@/lib/location/use-merchant-distance";
import {
  MERCHANT_TYPE_BADGE,
  MERCHANT_TYPE_LABELS,
  TAG_LABELS,
} from "@/lib/mock/merchants";
import { Card } from "@/components/ui/Card";
import { cn } from "@/lib/utils/cn";
import { FavoriteButton } from "./FavoriteButton";

function formatFromPrice(min: number) {
  return `desde $${min.toLocaleString("es-AR")}`;
}

export interface MerchantCardProps {
  merchant: Merchant;
  /**
   * "row" — the phone list-row layout (`places` in Fudo App.dc.html's
   * isList: 88×88 thumbnail + text). "card" — the wide grid-card layout
   * (`places` in Fudo Customers.dc.html's isList: full-width 16:10 photo on
   * top, type badge + favorite overlaid on it). Two real layouts, not a
   * CSS-only reflow — matches how differently the two references actually
   * compose this card.
   */
  layout: "row" | "card";
}

export function MerchantCard({ merchant, layout }: MerchantCardProps) {
  const typeBadge = MERCHANT_TYPE_BADGE[merchant.type];
  const visibleTags = merchant.tags.slice(0, 3);
  const priceLabel =
    merchant.price_per_person_min != null
      ? formatFromPrice(merchant.price_per_person_min)
      : null;
  // Real distance once the visitor activates location (Header's "Activar
  // ubicación" pill); falls back to merchant.distanceKm (currently always 0
  // for real API data — see lib/api/merchants.ts) until they do.
  const liveDistanceKm = useMerchantDistanceKm(merchant);
  const distanceKm = liveDistanceKm ?? merchant.distanceKm;

  if (layout === "card") {
    return (
      <Card
        as="article"
        className="group relative flex flex-col overflow-hidden transition-[transform,border-color] duration-200 hover:-translate-y-0.5 hover:border-accent/50"
      >
        <Link
          href={`/restaurantes/${merchant.id}`}
          className="relative block aspect-[16/10] w-full bg-surface-2"
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
            <div
              className="material-symbols flex h-full w-full items-center justify-center text-4xl"
              style={{ color: typeBadge.color }}
            >
              {typeBadge.icon}
            </div>
          )}
          <span
            className="absolute left-3 top-3 flex items-center gap-1.5 rounded-full bg-black/75 py-1.5 pl-2 pr-2.5 backdrop-blur-sm"
            style={{ color: typeBadge.color }}
          >
            <span aria-hidden className="material-symbols text-[15px]">
              {typeBadge.icon}
            </span>
            <span className="text-[11.5px] font-semibold text-white">
              {MERCHANT_TYPE_LABELS[merchant.type]}
            </span>
          </span>
          {merchant.rewardTeaser ? (
            <span className="absolute bottom-3 left-3 flex items-center gap-1 rounded-full bg-success px-2.5 py-1 text-[11.5px] font-bold text-[#10240A]">
              <span aria-hidden className="material-symbols text-[14px]">
                redeem
              </span>
              {merchant.rewardTeaser}
            </span>
          ) : null}
        </Link>
        <FavoriteButton
          merchantId={merchant.id}
          className="absolute right-3 top-3"
        />

        <div className="relative flex flex-col gap-1.5 p-4">
          <Link href={`/restaurantes/${merchant.id}`}>
            <h3 className="truncate font-heading text-xl font-extrabold text-foreground group-hover:text-accent-light">
              {merchant.name}
            </h3>
          </Link>
          <p className="truncate text-[13px] text-foreground-muted">
            {MERCHANT_TYPE_LABELS[merchant.type]} ·{" "}
            {merchant.neighborhood ?? merchant.city}
          </p>
          {merchant.topDish ? (
            <p className="truncate text-[12.5px] text-foreground-faint">
              {merchant.topDish}
            </p>
          ) : null}
          <div className="flex flex-wrap items-center gap-2.5 pt-1">
            {priceLabel ? (
              <span className="flex-none whitespace-nowrap rounded-full bg-accent-soft px-2.5 py-1 text-[13px] font-bold text-accent-light">
                {priceLabel}
              </span>
            ) : null}
            <span className="flex flex-none items-center gap-0.5 whitespace-nowrap text-[12.5px] text-foreground-faint">
              <span aria-hidden className="material-symbols text-[15px]">
                location_on
              </span>
              {distanceKm.toLocaleString("es-AR")} km
            </span>
          </div>
        </div>
      </Card>
    );
  }

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
          <div
            className="material-symbols flex h-full w-full items-center justify-center bg-surface-2 text-3xl"
            style={{ color: typeBadge.color }}
          >
            {typeBadge.icon}
          </div>
        )}
        <span
          className="material-symbols absolute bottom-1 left-1 flex h-6 w-6 items-center justify-center rounded-full bg-black/55 text-[14px] leading-none"
          style={{ color: typeBadge.color }}
        >
          {typeBadge.icon}
        </span>
      </Link>

      <div className="flex min-w-0 flex-1 flex-col gap-1 pt-0.5">
        <div className="flex items-start justify-between gap-2">
          <Link href={`/restaurantes/${merchant.id}`} className="min-w-0">
            <h3 className="truncate font-heading text-lg font-bold text-foreground hover:text-accent-light">
              {merchant.name}
            </h3>
          </Link>
          <FavoriteButton
            merchantId={merchant.id}
            variant="plain"
            className={cn("h-7 w-7 border-0 bg-transparent shadow-none")}
          />
        </div>
        <p className="truncate text-[12.5px] text-foreground-muted">
          {MERCHANT_TYPE_LABELS[merchant.type]} ·{" "}
          {merchant.neighborhood ?? merchant.city}
        </p>
        {merchant.topDish ? (
          <p className="truncate text-[12.5px] text-foreground-faint">
            {merchant.topDish}
          </p>
        ) : null}

        <div className="flex flex-wrap items-center gap-2 pt-1">
          {priceLabel ? (
            <span className="flex-none whitespace-nowrap rounded-full bg-accent-soft px-2.5 py-0.5 text-[12.5px] font-bold text-accent-light">
              {priceLabel}
            </span>
          ) : null}
          <span className="flex flex-none items-center gap-0.5 whitespace-nowrap text-[12.5px] text-foreground-faint">
            <span aria-hidden className="material-symbols text-[14px]">
              location_on
            </span>
            {distanceKm.toLocaleString("es-AR")} km
          </span>
          {merchant.rewardTeaser ? (
            <span className="flex items-center gap-0.5 text-[12px] font-semibold text-success">
              <span aria-hidden className="material-symbols text-[14px]">
                redeem
              </span>
              {merchant.rewardTeaser}
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
      </div>
    </article>
  );
}
