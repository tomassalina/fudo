"use client";

import Link from "next/link";
import type { Merchant } from "@/lib/types";
import { MERCHANT_TYPE_BADGE, MERCHANT_TYPE_LABELS } from "@/lib/mock/merchants";
import { useMerchantDistanceKm } from "@/lib/location/use-merchant-distance";
import { formatDistanceLabel } from "@/lib/utils/distance";
import { FavoriteButton } from "./FavoriteButton";

function formatFromPrice(min: number) {
  return `desde $${min.toLocaleString("es-AR")}`;
}

export interface MerchantMapCardProps {
  merchant: Merchant;
  onClose: () => void;
  /** Advances the map to the next pin's card. Omitted (no arrow rendered) when the map only has this one pin. */
  onNext?: () => void;
}

/**
 * The pin's detail card — a real card (photo, name, reward teaser as our
 * rating-equivalent, price, favorite, close, "next result" arrow), not just
 * a name in a tooltip. Same *interaction pattern* as Airbnb/Google Maps'
 * "tap a pin, a card appears over the map" — deliberately NOT their light
 * visual style; built from the same dark surface/border/accent tokens every
 * other /buscar card uses (see MerchantCard.tsx, whose "card" layout this
 * mirrors closely).
 *
 * Rendered as the content of a react-leaflet <Popup> (see LeafletMap.tsx),
 * with Leaflet's own popup chrome (white wrapper, tail, default close
 * button) stripped via leaflet-map.css so this card *is* the entire visible
 * popup — `onClose`/`onNext` are wired to the owning Marker's imperative
 * open/closePopup() there, since Leaflet's Popup has no "controlled open"
 * React prop to hook a Next.js <Link>-style navigation into.
 */
export function MerchantMapCard({ merchant, onClose, onNext }: MerchantMapCardProps) {
  const typeBadge = MERCHANT_TYPE_BADGE[merchant.type];
  const priceLabel =
    merchant.price_per_person_min != null
      ? formatFromPrice(merchant.price_per_person_min)
      : null;
  const liveDistanceKm = useMerchantDistanceKm(merchant);
  const distanceKm = liveDistanceKm ?? merchant.distanceKm;

  return (
    <div className="w-[248px] overflow-hidden rounded-2xl border border-border bg-surface shadow-xl shadow-black/50">
      <div className="relative aspect-[16/10] w-full bg-surface-2">
        <Link href={`/restaurantes/${merchant.id}`} className="absolute inset-0 block">
          {merchant.cover_image_url ? (
            // eslint-disable-next-line @next/next/no-img-element -- external mock photos, same tradeoff MerchantCard already makes
            <img
              src={merchant.cover_image_url}
              alt={merchant.name}
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
        </Link>

        <FavoriteButton merchantId={merchant.id} className="absolute left-2.5 top-2.5" />

        <button
          type="button"
          onClick={onClose}
          aria-label="Cerrar"
          className="absolute right-2.5 top-2.5 flex h-8 w-8 items-center justify-center rounded-full bg-black/65 text-white backdrop-blur-sm transition-transform active:scale-90"
        >
          <span aria-hidden className="material-symbols text-[17px]">
            close
          </span>
        </button>

        {onNext ? (
          <button
            type="button"
            onClick={onNext}
            aria-label="Ver el siguiente lugar"
            className="absolute right-2.5 top-1/2 flex h-8 w-8 -translate-y-1/2 items-center justify-center rounded-full bg-black/65 text-white backdrop-blur-sm transition-transform active:scale-90"
          >
            <span aria-hidden className="material-symbols text-[19px]">
              chevron_right
            </span>
          </button>
        ) : null}
      </div>

      <div className="flex flex-col gap-1.5 p-3">
        <Link href={`/restaurantes/${merchant.id}`}>
          <h3 className="truncate font-heading text-[15px] font-extrabold text-foreground hover:text-accent-light">
            {merchant.name}
          </h3>
        </Link>
        <p className="truncate text-[12px] text-foreground-muted">
          {MERCHANT_TYPE_LABELS[merchant.type]} · {merchant.neighborhood ?? merchant.city}
        </p>

        {/* Reward teaser stands in for the "rating" row Airbnb/Google Maps
            cards have — we have no star rating, but this is the closest real
            equivalent (see MerchantCard's own row layout, same treatment).
            Omitted entirely rather than showing a fake/empty rating when a
            merchant has none. */}
        {merchant.rewardTeaser ? (
          <p className="flex items-center gap-1 truncate text-[12px] font-semibold text-success">
            <span aria-hidden className="material-symbols text-[14px]">
              redeem
            </span>
            {merchant.rewardTeaser}
          </p>
        ) : null}

        <div className="flex flex-wrap items-center gap-2 pt-0.5">
          {priceLabel ? (
            <span className="rounded-full bg-accent-soft px-2.5 py-1 text-[12.5px] font-bold text-accent-light">
              {priceLabel}
            </span>
          ) : null}
          <span className="flex items-center gap-0.5 text-[12px] text-foreground-faint">
            <span aria-hidden className="material-symbols text-[14px]">
              location_on
            </span>
            {formatDistanceLabel(distanceKm)}
          </span>
        </div>
      </div>
    </div>
  );
}
