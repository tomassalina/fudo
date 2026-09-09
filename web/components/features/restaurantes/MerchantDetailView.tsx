"use client";

import Link from "next/link";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { FavoriteButton } from "@/components/features/buscar/FavoriteButton";
import { FluidContainer } from "@/components/ui/FluidContainer";
import { MERCHANT_TYPE_BADGE, MERCHANT_TYPE_LABELS } from "@/lib/mock/merchants";
import { DAY_LABELS_SHORT, formatDayHours } from "@/lib/mock/business-hours";
import type { DayHours } from "@/lib/mock/business-hours";
import type { Merchant, MenuItem } from "@/lib/types";
import { cn } from "@/lib/utils/cn";
import { formatPrice } from "@/lib/utils/format-price";
import { DetailTabs } from "./DetailTabs";
import { LoyaltyCard } from "./LoyaltyCard";

/** wa.me only wants digits — strip the leading "+" and any formatting. Kept
 * as a tiny local copy (not imported from the server page) so this client
 * bundle doesn't pull in page.tsx's module graph for one two-line helper. */
function whatsappLink(number: string) {
  return `https://wa.me/${number.replace(/[^\d]/g, "")}`;
}

/** Same shape `groupMenuItemsBySection` (lib/mock/menu-items.ts) returns. */
interface MenuItemGroup {
  section: string;
  items: MenuItem[];
}

export interface MerchantDetailViewProps {
  merchant: Merchant;
  /** Already formatted, e.g. "$13.000 – $25.000 por persona" — computed
   * server-side in page.tsx, where the same string is also needed for
   * generateMetadata's SEO description. */
  priceRange: string | null;
  weekHours: DayHours[];
  menuGroups: MenuItemGroup[];
}

/**
 * The phone/wide structural switch for the merchant detail page — same
 * pattern as `BuscarView` (components/features/buscar/BuscarView.tsx) and
 * `AppNav`: `useIsPhoneViewport()` picks genuinely different structure, not
 * a CSS-only reflow. Below 900px this mirrors
 * `docs/design-reference/Fudo App.dc.html`'s `isDetail` branch (edge-to-edge
 * 232px cover photo with back/favorite overlaid on it, title stacked below,
 * single column). At/above 900px this mirrors
 * `docs/design-reference/Fudo Customers.dc.html`'s `isDetail` branch: a
 * ~1760px-capped container, a text "Volver a los resultados" link above a
 * taller 340px hero with the title overlaid on it, and a two-column grid
 * below — a sticky `position: sticky; top: 96px` left rail (hours + price/
 * distance/contact) next to the tabs (loyalty/menu) in the wider column.
 *
 * The hours list is always rendered fully expanded in both layouts (no
 * collapse/expand accordion) — same simplification already made for the
 * phone layout (see this component's `hoursCard`), since this is static SSG
 * output with no client state to back a toggle.
 */
export function MerchantDetailView({
  merchant,
  priceRange,
  weekHours,
  menuGroups,
}: MerchantDetailViewProps) {
  const isPhone = useIsPhoneViewport();
  const typeBadge = MERCHANT_TYPE_BADGE[merchant.type];
  const typeLabel = MERCHANT_TYPE_LABELS[merchant.type];

  // Item cards themselves are identical between layouts; only the group's
  // wrapping grid differs — a single column on phone (`display: flex;
  // flex-direction: column` in the App.dc.html isDetail branch) vs. a fluid
  // `repeat(auto-fit, minmax(300px, 1fr))` grid on wide (Fudo
  // Customers.dc.html's isDetail branch) — so this stays one `isPhone`
  // branch instead of a CSS-only reflow that would also kick in on a narrow
  // *wide-layout* window.
  const menuSection =
    menuGroups.length > 0 ? (
      <section className="flex flex-col gap-5">
        {menuGroups.map((group) => (
          <div key={group.section}>
            <div className="flex items-baseline justify-between pb-2.5">
              <h2 className="text-[11px] font-bold uppercase tracking-widest text-foreground-faint">
                {group.section}
              </h2>
              <span className="text-[11.5px] text-foreground-faint">
                {group.items.length}{" "}
                {group.items.length === 1 ? "plato" : "platos"}
              </span>
            </div>
            <div
              className={cn(
                "gap-2.5",
                isPhone
                  ? "flex flex-col"
                  : "grid grid-cols-[repeat(auto-fit,minmax(300px,1fr))]",
              )}
            >
              {group.items.map((item) => (
                <div
                  key={item.id}
                  className="flex items-start gap-3 rounded-2xl border border-border bg-surface p-2.5 shadow-inner shadow-white/5"
                >
                  <div className="h-[70px] w-[70px] flex-none overflow-hidden rounded-xl bg-surface-2">
                    {item.image_url ? (
                      // eslint-disable-next-line @next/next/no-img-element -- external mock photos, not worth Image config for this low-priority pass
                      <img
                        src={item.image_url}
                        alt={item.name}
                        loading="lazy"
                        className="h-full w-full object-cover"
                      />
                    ) : null}
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="text-[14.5px] font-semibold text-foreground">
                      {item.name}
                    </p>
                    {item.description ? (
                      <p className="pt-0.5 text-[12.5px] leading-snug text-foreground-muted">
                        {item.description}
                      </p>
                    ) : null}
                  </div>
                  <div className="flex-none text-right">
                    <p className="font-heading text-[17px] font-extrabold text-foreground">
                      {formatPrice(item.price)}
                    </p>
                    <p className="pt-0.5 text-[10px] uppercase text-foreground-faint">
                      {item.currency}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        ))}
      </section>
    ) : (
      <p className="py-8 text-center text-[13px] text-foreground-muted">
        Este local todavía no cargó su menú.
      </p>
    );

  const hoursCard = (
    <div className="flex flex-col gap-1.5 rounded-2xl border border-border bg-surface p-3 shadow-inner shadow-white/5">
      {weekHours.map((dayHours) => (
        <div
          key={dayHours.day}
          className="flex items-baseline justify-between gap-3 text-[13px]"
        >
          <span className="font-semibold text-foreground">
            {DAY_LABELS_SHORT[dayHours.day]}
          </span>
          <span
            className={
              dayHours.closed
                ? "text-foreground-faint"
                : "text-right text-foreground-muted"
            }
          >
            {formatDayHours(dayHours)}
          </span>
        </div>
      ))}
    </div>
  );

  // `fullWidth` matches the wide reference's `flex: 1` buttons (share the
  // card's width evenly); the phone reference lets them hug their content —
  // same two `<a>`s, just a different className, so this stays one function
  // instead of two near-duplicate JSX blocks.
  function contactButtons(fullWidth: boolean) {
    if (!merchant.whatsapp_number && !merchant.delivery_url) return null;
    return (
      <div className="flex gap-2">
        {merchant.whatsapp_number ? (
          <a
            href={whatsappLink(merchant.whatsapp_number)}
            target="_blank"
            rel="noreferrer"
            className={cn(
              "flex items-center justify-center gap-1.5 rounded-full border border-border bg-surface px-3.5 py-2 text-[12.5px] font-semibold text-foreground shadow-inner shadow-white/5",
              fullWidth && "flex-1",
            )}
          >
            <span className="material-symbols text-[16px]">chat</span>
            WhatsApp
          </a>
        ) : null}
        {merchant.delivery_url ? (
          <a
            href={merchant.delivery_url}
            target="_blank"
            rel="noreferrer"
            className={cn(
              "flex items-center justify-center gap-1.5 rounded-full bg-linear-to-b from-accent-light to-accent-dark px-3.5 py-2 text-[12.5px] font-semibold text-white shadow-lg shadow-accent/30",
              fullWidth && "flex-1",
            )}
          >
            <span className="material-symbols text-[16px]">
              delivery_dining
            </span>
            Delivery
          </a>
        ) : null}
      </div>
    );
  }

  const tabs = (
    <DetailTabs
      loyaltySection={<LoyaltyCard merchant={merchant} />}
      menuSection={menuSection}
      fitWidth={!isPhone}
    />
  );

  if (!isPhone) {
    return (
      <FluidContainer as="div" className="flex flex-col pb-20 pt-6">
        <Link
          href="/buscar"
          className="mb-4 flex w-fit items-center gap-2 text-[13.5px] font-semibold text-foreground-muted"
        >
          <span className="material-symbols text-[19px]">arrow_back</span>
          Volver a los resultados
        </Link>

        <div className="relative h-[340px] w-full flex-none overflow-hidden rounded-[24px] border border-border bg-surface-2">
          {merchant.cover_image_url ? (
            // eslint-disable-next-line @next/next/no-img-element -- external mock photos, not worth Image config for this low-priority pass
            <img
              src={merchant.cover_image_url}
              alt={merchant.name}
              className="h-full w-full object-cover"
            />
          ) : (
            <div
              className="material-symbols flex h-full w-full items-center justify-center text-6xl"
              style={{ color: typeBadge.color }}
            >
              {typeBadge.icon}
            </div>
          )}
          <span
            aria-hidden
            className="absolute inset-0 bg-linear-to-b from-black/35 via-transparent to-black/75"
          />
          <FavoriteButton
            merchantId={merchant.id}
            className="absolute right-4 top-4 backdrop-blur"
          />
          <div className="absolute inset-x-7 bottom-6">
            <h1 className="font-heading text-[clamp(28px,3.4vw,44px)] font-black leading-tight text-white">
              {merchant.name}
            </h1>
            <p className="pt-2 text-[14.5px] text-white/80">
              {typeLabel} · {merchant.neighborhood ?? merchant.city} ·{" "}
              {merchant.address}
            </p>
          </div>
        </div>

        <div
          className="grid items-start gap-7 pt-6"
          style={{ gridTemplateColumns: "minmax(280px, 340px) minmax(0, 1fr)" }}
        >
          <div className="sticky top-24 flex min-w-0 flex-col gap-3.5">
            <div>
              <h2 className="pb-2.5 text-[11px] font-bold uppercase tracking-widest text-foreground-faint">
                Horarios
              </h2>
              {hoursCard}
            </div>

            <div className="flex flex-col gap-3 rounded-2xl border border-border bg-surface p-4 shadow-inner shadow-white/5">
              {priceRange ? (
                <div>
                  <div className="text-[11px] font-bold tracking-widest text-foreground-faint">
                    PRECIO POR PERSONA
                  </div>
                  <div className="pt-1.5 font-heading text-xl font-extrabold text-foreground">
                    {priceRange}
                  </div>
                </div>
              ) : null}
              <span className="flex items-center gap-1.5 text-[13px] text-foreground-muted">
                <span className="material-symbols text-[16px]">near_me</span>
                {merchant.distanceKm.toLocaleString("es-AR")} km de tu
                ubicación
              </span>
              {contactButtons(true)}
            </div>
          </div>

          <div className="min-w-0">{tabs}</div>
        </div>
      </FluidContainer>
    );
  }

  return (
    <div className="mx-auto flex w-full max-w-3xl flex-1 flex-col pb-28">
      <div className="relative h-[232px] w-full flex-none bg-surface-2">
        {merchant.cover_image_url ? (
          // eslint-disable-next-line @next/next/no-img-element -- external mock photos, not worth Image config for this low-priority pass
          <img
            src={merchant.cover_image_url}
            alt={merchant.name}
            className="h-full w-full object-cover"
          />
        ) : (
          <div
            className="material-symbols flex h-full w-full items-center justify-center text-6xl"
            style={{ color: typeBadge.color }}
          >
            {typeBadge.icon}
          </div>
        )}
        <span
          aria-hidden
          className="absolute inset-0 bg-linear-to-b from-black/45 via-transparent to-background"
        />
        <Link
          href="/buscar"
          className="material-symbols absolute left-4 top-3 flex h-9 w-9 items-center justify-center rounded-full bg-black/60 text-white backdrop-blur"
        >
          arrow_back
        </Link>
        <FavoriteButton
          merchantId={merchant.id}
          className="absolute right-4 top-3 backdrop-blur"
        />
      </div>

      <div className="flex flex-col gap-4 px-5 pt-1 sm:px-6">
        <div>
          <h1 className="font-heading text-[27px] font-black leading-tight text-foreground">
            {merchant.name}
          </h1>
          <p className="flex items-center gap-1 pt-1 text-[13px] text-foreground-muted">
            <span
              className="material-symbols text-[15px]"
              style={{ color: typeBadge.color }}
            >
              {typeBadge.icon}
            </span>
            {typeLabel} · {merchant.neighborhood ?? merchant.city}
          </p>
          <p className="flex items-center gap-1.5 pt-1.5 text-[12.5px] text-foreground-faint">
            <span className="material-symbols text-[15px]">place</span>
            {merchant.address}
            {merchant.neighborhood ? `, ${merchant.neighborhood}` : ""},{" "}
            {merchant.city}
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          {priceRange ? (
            <span className="rounded-full bg-accent-soft px-3 py-1 text-[13px] font-bold text-accent-light">
              {priceRange}
            </span>
          ) : null}
          <span className="flex items-center gap-1 text-[13px] text-foreground-muted">
            <span className="material-symbols text-[15px]">near_me</span>
            {merchant.distanceKm.toLocaleString("es-AR")} km
          </span>
        </div>

        {contactButtons(false)}

        <section>
          <h2 className="pb-2.5 text-[11px] font-bold uppercase tracking-widest text-foreground-faint">
            Horarios
          </h2>
          {hoursCard}
        </section>

        <div className="pt-2">{tabs}</div>
      </div>
    </div>
  );
}
