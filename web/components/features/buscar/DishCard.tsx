"use client";

import Link from "next/link";
import type { DishSearchResult } from "@/lib/types";
import { useMerchantDistanceKm } from "@/lib/location/use-merchant-distance";
import { TAG_LABELS } from "@/lib/mock/merchants";

function formatPrice(value: number) {
  return `$${value.toLocaleString("es-AR")}`;
}

export interface DishCardProps {
  result: DishSearchResult;
  /** Same row/card split as MerchantCard — see its doc comment. */
  layout: "row" | "card";
}

/** The "Platos" result-mode card (`dishList`/`d` in both design references):
 * a menu item plus the merchant serving it. */
export function DishCard({ result, layout }: DishCardProps) {
  const { item, merchant } = result;
  const visibleTags = merchant.tags.slice(0, 2);
  // Real distance once the visitor activates location (Header's "Activar
  // ubicación" pill); falls back to merchant.distanceKm (currently always 0
  // for real API data — see lib/api/merchants.ts) until they do.
  const liveDistanceKm = useMerchantDistanceKm(merchant);
  const distanceKm = liveDistanceKm ?? merchant.distanceKm;

  if (layout === "card") {
    return (
      <Link
        href={`/restaurantes/${merchant.id}`}
        className="group flex flex-col overflow-hidden rounded-card border border-border bg-surface shadow-[inset_0_1px_0_var(--highlight)] transition-[transform,border-color] duration-200 hover:-translate-y-0.5 hover:border-accent/50"
      >
        <div
          role="img"
          aria-label={item.name}
          className="aspect-[16/10] w-full bg-surface-2 bg-cover bg-center"
          style={
            item.image_url ? { backgroundImage: `url(${item.image_url})` } : undefined
          }
        />
        <div className="flex flex-col gap-1.5 p-4">
          <div className="flex items-start justify-between gap-2.5">
            <h3 className="min-w-0 text-[15.5px] font-semibold text-foreground">
              {item.name}
            </h3>
            <span className="flex-none rounded-full bg-accent-soft px-2.5 py-1 text-[12.5px] font-bold text-accent-light">
              {formatPrice(item.price)}
            </span>
          </div>
          {item.description ? (
            <p className="text-[12.5px] leading-snug text-foreground-muted">
              {item.description}
            </p>
          ) : null}
          <div className="flex items-center gap-2 pt-0.5">
            <span className="truncate text-[12.5px] font-semibold text-foreground">
              {merchant.name}
            </span>
            <span className="flex flex-none items-center gap-0.5 text-[12px] text-foreground-faint">
              <span aria-hidden className="material-symbols text-[14px]">
                location_on
              </span>
              {distanceKm.toLocaleString("es-AR")} km
            </span>
          </div>
          {visibleTags.length > 0 ? (
            <div className="flex gap-1.5 pt-0.5">
              {visibleTags.map((tag) => (
                <span
                  key={tag}
                  className="rounded-full bg-success-soft px-2 py-0.5 text-[10.5px] font-bold text-success"
                >
                  {TAG_LABELS[tag] ?? tag}
                </span>
              ))}
            </div>
          ) : null}
        </div>
      </Link>
    );
  }

  return (
    <Link
      href={`/restaurantes/${merchant.id}`}
      className="flex gap-3 rounded-[18px] border border-border bg-surface p-2.5 shadow-inner shadow-white/5 transition-colors hover:border-accent/50"
    >
      <div
        role="img"
        aria-label={item.name}
        className="h-[88px] w-[88px] flex-none rounded-[13px] bg-surface-2 bg-cover bg-center"
        style={
          item.image_url ? { backgroundImage: `url(${item.image_url})` } : undefined
        }
      />
      <div className="flex min-w-0 flex-1 flex-col gap-1 pt-0.5">
        <div className="flex items-start justify-between gap-2">
          <h3 className="min-w-0 text-[14.5px] font-semibold text-foreground">
            {item.name}
          </h3>
          <span className="flex-none rounded-full bg-accent-soft px-2.5 py-0.5 text-[12.5px] font-bold text-accent-light">
            {formatPrice(item.price)}
          </span>
        </div>
        {item.description ? (
          <p className="line-clamp-2 text-[12px] leading-snug text-foreground-muted">
            {item.description}
          </p>
        ) : null}
        <div className="flex items-center gap-2 pt-0.5">
          <span className="truncate text-[12px] font-semibold text-foreground">
            {merchant.name}
          </span>
          <span className="flex flex-none items-center gap-0.5 text-[11.5px] text-foreground-faint">
            <span aria-hidden className="material-symbols text-[14px]">
              location_on
            </span>
            {distanceKm.toLocaleString("es-AR")} km
          </span>
        </div>
        {visibleTags.length > 0 ? (
          <div className="flex gap-1.5">
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
    </Link>
  );
}
