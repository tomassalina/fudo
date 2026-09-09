"use client";

// Featured places on the home page. The design reference's own `isHome`
// view has no bound featured-places data (its "popular" row is an unwired
// `hint-placeholder-count="4"` stub — see docs/design-reference/
// Fudo Customers.dc.html), so this section's card visuals are drawn from the
// one place the reference *does* render real merchant cards in a grid: the
// `isList` grid-card layout (image, type badge, name, reward chip — see the
// same file's `{{ places }}` grid). Layout is exactly what the task calls
// for: a horizontally scrollable row on phone, the theme's `grid-cards`
// CSS Grid auto-fit utility on wide — switched on the same 900px breakpoint
// as the rest of the app (useIsPhoneViewport), not a new media query.
//
// The phone row's edge-to-edge bleed reuses the exact fluid padding
// FluidContainer applies (clamp(16px, 3vw, 32px), see .container-fluid in
// app/globals.css) instead of a fixed 24px, so the cards stay aligned with
// the section's own padding at every width instead of only at >=768px.

import Link from "next/link";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { useMerchantDistanceKm } from "@/lib/location/use-merchant-distance";
import { MERCHANT_TYPE_BADGE, MERCHANT_TYPE_LABELS } from "@/lib/mock/merchants";
import type { Merchant } from "@/lib/types";
import { cn } from "@/lib/utils/cn";

function formatFromPrice(min: number) {
  return `desde $${min.toLocaleString("es-AR")}`;
}

function FeaturedCard({ merchant }: { merchant: Merchant }) {
  const typeBadge = MERCHANT_TYPE_BADGE[merchant.type];
  // Real distance once the visitor activates location (Header's "Activar
  // ubicación" pill); falls back to merchant.distanceKm (currently always 0
  // for real API data — see lib/api/merchants.ts) until they do.
  const liveDistanceKm = useMerchantDistanceKm(merchant);
  const distanceKm = liveDistanceKm ?? merchant.distanceKm;

  return (
    <Link
      href={`/restaurantes/${merchant.id}`}
      className="block flex-none animate-fudo-in overflow-hidden rounded-card border border-border bg-surface shadow-[inset_0_1px_0_var(--highlight)] transition-[transform,border-color] duration-200 hover:-translate-y-[3px] hover:border-accent/50"
    >
      <div className="relative aspect-[16/10] bg-surface-2">
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
        <span className="absolute left-3 top-3 flex items-center gap-1.5 rounded-full bg-black/[.78] px-2.5 py-1.5 backdrop-blur-[6px]">
          <span
            className="material-symbols text-[15px]"
            style={{ color: typeBadge.color }}
          >
            {typeBadge.icon}
          </span>
          <span className="text-[11.5px] font-semibold text-white">
            {MERCHANT_TYPE_LABELS[merchant.type]}
          </span>
        </span>
        {merchant.rewardTeaser ? (
          <span className="absolute bottom-3 left-3 flex items-center gap-1 rounded-full bg-success/90 px-2.5 py-1">
            <span className="material-symbols text-[14px] text-[#10240A]">
              redeem
            </span>
            <span className="text-[11.5px] font-bold text-[#10240A]">
              {merchant.rewardTeaser}
            </span>
          </span>
        ) : null}
      </div>

      <div className="flex flex-col gap-1.5 px-4 pb-4.5 pt-4">
        <h3 className="truncate font-heading text-xl font-extrabold text-foreground">
          {merchant.name}
        </h3>
        <p className="truncate text-[12.5px] text-foreground-muted">
          {merchant.neighborhood ?? merchant.city}
        </p>
        <div className="flex items-center gap-2 pt-0.5">
          {merchant.price_per_person_min != null ? (
            <span className="flex-none whitespace-nowrap rounded-full bg-accent-soft px-2.5 py-0.5 text-[12.5px] font-bold text-accent-light">
              {formatFromPrice(merchant.price_per_person_min)}
            </span>
          ) : null}
          <span className="flex flex-none items-center gap-0.5 whitespace-nowrap text-[12.5px] text-foreground-faint">
            <span className="material-symbols text-[14px]">location_on</span>
            {distanceKm.toLocaleString("es-AR")} km
          </span>
        </div>
      </div>
    </Link>
  );
}

export function FeaturedGrid({ merchants }: { merchants: Merchant[] }) {
  const isPhone = useIsPhoneViewport();

  if (merchants.length === 0) {
    return null;
  }

  return (
    <div
      className={cn(
        isPhone
          ? "-mx-[clamp(16px,3vw,32px)] flex gap-3 overflow-x-auto px-[clamp(16px,3vw,32px)]"
          : "grid-cards",
      )}
    >
      {merchants.map((merchant) => (
        <div key={merchant.id} className={isPhone ? "w-[220px]" : undefined}>
          <FeaturedCard merchant={merchant} />
        </div>
      ))}
    </div>
  );
}
