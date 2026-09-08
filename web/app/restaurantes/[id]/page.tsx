// Public, SSR/SSG merchant detail page — the actual reason this Next.js app
// exists per the PRD ("que Google indexe cada restaurante"): every merchant
// gets its own crawlable, individually-indexable URL with real per-merchant
// <title>/description/OpenGraph tags, instead of only the /buscar list.
//
// Server Component, statically generated at build time for all 30 mock
// merchants (see generateStaticParams below) — cheap to do since the whole
// dataset is a local mock module, and it's the better fit for the stated SEO
// goal (fully static HTML per restaurant, no per-request work).
//
// Layout below mirrors the design reference's own merchant-detail artboard
// (docs/design-reference/Fudo App.dc.html, the `isDetail` branch: cover photo
// with gradient + back button, Barlow 900 name, meta/address lines, price +
// distance row, WhatsApp/Delivery pill buttons, a plain weekly hours list —
// same "Cerrado" / day-label / "HH:MM–HH:MM" conventions as that artboard's
// hours accordion, just without the collapse/expand interaction, since this
// is static SSG output — then menu items grouped by section. The
// loyalty-progress tab from that same artboard is still deferred: it needs a
// loyalty_rules join this mock layer doesn't expose yet.
//
// Also carries a schema.org JSON-LD block (Restaurant/FoodEstablishment,
// depending on merchant.type — see SCHEMA_ORG_TYPE below) built from the same
// merchant + business_hours data, the structured-data half of the SEO work.

import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import {
  buildOpeningHoursSpecification,
  DAY_LABELS_SHORT,
  formatDayHours,
  getBusinessHoursForMerchant,
  groupBusinessHoursByDay,
} from "@/lib/mock/business-hours";
import type { DayHours } from "@/lib/mock/business-hours";
import {
  MERCHANT_COUNTRY_CODE,
  MERCHANT_TYPE_BADGE,
  MERCHANT_TYPE_LABELS,
  MOCK_MERCHANTS,
} from "@/lib/mock/merchants";
import {
  getMenuItemsForMerchant,
  groupMenuItemsBySection,
} from "@/lib/mock/menu-items";
import type { Merchant, MerchantType } from "@/lib/types";

function findMerchant(id: string): Merchant | undefined {
  const numericId = Number(id);
  if (!Number.isInteger(numericId)) return undefined;
  return MOCK_MERCHANTS.find((merchant) => merchant.id === numericId);
}

function formatPrice(value: number) {
  return `$${value.toLocaleString("es-AR")}`;
}

/** e.g. "$13.000 – $25.000 por persona", or a single value if min === max. */
function formatPriceRange(merchant: Merchant) {
  const { price_per_person_min: min, price_per_person_max: max } = merchant;
  if (min == null && max == null) return null;
  if (min != null && max != null && min !== max) {
    return `${formatPrice(min)} – ${formatPrice(max)} por persona`;
  }
  return `${formatPrice(min ?? max!)} por persona`;
}

/** wa.me only wants digits — strip the leading "+" and any formatting. */
function whatsappLink(number: string) {
  return `https://wa.me/${number.replace(/[^\d]/g, "")}`;
}

// schema.org has no single type that covers every MerchantType — pick the
// closest FoodEstablishment subtype per type, falling back to the generic
// FoodEstablishment for the ones with no good match (food_truck, dark_kitchen,
// other have no dine-in-shaped schema.org type).
const SCHEMA_ORG_TYPE: Record<MerchantType, string> = {
  restaurant: "Restaurant",
  pizzeria: "Restaurant",
  cafe: "CafeOrCoffeeShop",
  bar: "BarOrPub",
  brewery: "BarOrPub",
  food_truck: "FoodEstablishment",
  dark_kitchen: "FoodEstablishment",
  other: "FoodEstablishment",
};

/** "$" / "$$" / "$$$" from the average of price_per_person_min/max — thresholds picked from this fixture's own ~30-merchant spread (roughly even tertiles). */
function schemaPriceRange(merchant: Merchant): string | undefined {
  const { price_per_person_min: min, price_per_person_max: max } = merchant;
  if (min == null && max == null) return undefined;
  const avg = min != null && max != null ? (min + max) / 2 : (min ?? max)!;
  if (avg <= 25000) return "$";
  if (avg <= 60000) return "$$";
  return "$$$";
}

/**
 * schema.org Restaurant/FoodEstablishment JSON-LD for this merchant — the
 * structured-data half of the SEO work the PRD calls for (metadata/OG tags
 * cover the rest). openingHoursSpecification is derived from the same
 * grouped/validated weekHours the visible "Horarios" section renders (via
 * buildOpeningHoursSpecification), so the two can't silently drift apart and
 * overnight shifts get split into two entries the same way in both places;
 * closed days are simply omitted, the standard convention. servesCuisine is
 * left out because none of this merchant's tags (vegano/sin_tacc/picante/...)
 * are actual cuisine names, just dietary/attribute tags.
 */
function buildJsonLd(merchant: Merchant, weekHours: DayHours[]) {
  const priceRange = schemaPriceRange(merchant);
  const openingHoursSpecification = buildOpeningHoursSpecification(weekHours);

  return {
    "@context": "https://schema.org",
    "@type": SCHEMA_ORG_TYPE[merchant.type],
    name: merchant.name,
    address: {
      "@type": "PostalAddress",
      streetAddress: merchant.address,
      addressLocality: merchant.city,
      addressRegion: merchant.state,
      // ISO 3166-1 alpha-2, per Google's Rich Results guidance — not the
      // full country name (merchant.country stays "Argentina" for display).
      addressCountry: MERCHANT_COUNTRY_CODE,
    },
    geo: {
      "@type": "GeoCoordinates",
      latitude: merchant.latitude,
      longitude: merchant.longitude,
    },
    ...(merchant.cover_image_url ? { image: merchant.cover_image_url } : {}),
    ...(priceRange ? { priceRange } : {}),
    ...(openingHoursSpecification.length > 0
      ? { openingHoursSpecification }
      : {}),
  };
}

export async function generateStaticParams() {
  return MOCK_MERCHANTS.map((merchant) => ({ id: String(merchant.id) }));
}

export async function generateMetadata({
  params,
}: PageProps<"/restaurantes/[id]">): Promise<Metadata> {
  const { id } = await params;
  const merchant = findMerchant(id);

  if (!merchant) {
    return { title: "Restaurante no encontrado" };
  }

  const typeLabel = MERCHANT_TYPE_LABELS[merchant.type];
  const priceRange = formatPriceRange(merchant);
  // Falls back to city when neighborhood is null (schema allows it) so SEO
  // title/description never render the literal string "null".
  const locationLabel = merchant.neighborhood ?? merchant.city;
  const description = [
    `${typeLabel} en ${locationLabel}.`,
    priceRange,
    merchant.topDish ? `Probá: ${merchant.topDish}.` : null,
  ]
    .filter(Boolean)
    .join(" ");

  return {
    title: `${merchant.name} — ${typeLabel} en ${locationLabel} | Fudo`,
    description,
    openGraph: {
      title: merchant.name,
      description,
      type: "website",
      ...(merchant.cover_image_url
        ? { images: [{ url: merchant.cover_image_url }] }
        : {}),
    },
  };
}

export default async function MerchantPage({
  params,
}: PageProps<"/restaurantes/[id]">) {
  const { id } = await params;
  const merchant = findMerchant(id);

  if (!merchant) {
    notFound();
  }

  const typeBadge = MERCHANT_TYPE_BADGE[merchant.type];
  const priceRange = formatPriceRange(merchant);
  const menuGroups = groupMenuItemsBySection(
    getMenuItemsForMerchant(merchant.id),
  );
  const businessHours = getBusinessHoursForMerchant(merchant.id);
  const weekHours = groupBusinessHoursByDay(businessHours);
  const jsonLd = buildJsonLd(merchant, weekHours);

  return (
    <main className="mx-auto flex w-full max-w-3xl flex-1 flex-col pb-16">
      {/* Structured data for search engines — static, server-derived JSON, no user input involved. */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <div className="relative h-[232px] w-full flex-none bg-surface-2">
        {merchant.cover_image_url ? (
          // eslint-disable-next-line @next/next/no-img-element -- external mock photos, not worth Image config for this low-priority pass
          <img
            src={merchant.cover_image_url}
            alt={merchant.name}
            className="h-full w-full object-cover"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center text-6xl">
            {typeBadge}
          </div>
        )}
        <span
          aria-hidden
          className="absolute inset-0 bg-linear-to-b from-black/45 via-transparent to-background"
        />
        <Link
          href="/buscar"
          className="absolute left-4 top-3 flex h-9 w-9 items-center justify-center rounded-full bg-black/60 text-white backdrop-blur"
        >
          ←
        </Link>
      </div>

      <div className="flex flex-col gap-4 px-5 pt-1 sm:px-6">
        <div>
          <h1 className="font-heading text-[27px] font-black leading-tight text-foreground">
            {merchant.name}
          </h1>
          <p className="pt-1 text-[13px] text-foreground-muted">
            {typeBadge} {MERCHANT_TYPE_LABELS[merchant.type]} ·{" "}
            {merchant.neighborhood ?? merchant.city}
          </p>
          <p className="flex items-center gap-1.5 pt-1.5 text-[12.5px] text-foreground-faint">
            📍 {merchant.address}, {merchant.city}
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          {priceRange ? (
            <span className="rounded-full bg-accent-soft px-3 py-1 text-[13px] font-bold text-accent-light">
              {priceRange}
            </span>
          ) : null}
          <span className="flex items-center gap-1 text-[13px] text-foreground-muted">
            🧭 {merchant.distanceKm.toLocaleString("es-AR")} km
          </span>
        </div>

        {merchant.whatsapp_number || merchant.delivery_url ? (
          <div className="flex gap-2">
            {merchant.whatsapp_number ? (
              <a
                href={whatsappLink(merchant.whatsapp_number)}
                target="_blank"
                rel="noreferrer"
                className="flex items-center gap-1.5 rounded-full border border-border bg-surface px-3.5 py-2 text-[12.5px] font-semibold text-foreground shadow-inner shadow-white/5"
              >
                💬 WhatsApp
              </a>
            ) : null}
            {merchant.delivery_url ? (
              <a
                href={merchant.delivery_url}
                target="_blank"
                rel="noreferrer"
                className="flex items-center gap-1.5 rounded-full bg-linear-to-b from-accent-light to-accent-dark px-3.5 py-2 text-[12.5px] font-semibold text-white shadow-lg shadow-accent/30"
              >
                🛵 Delivery
              </a>
            ) : null}
          </div>
        ) : null}

        <section>
          <h2 className="pb-2.5 text-[11px] font-bold uppercase tracking-widest text-foreground-faint">
            Horarios
          </h2>
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
        </section>

        {menuGroups.length > 0 ? (
          <section className="flex flex-col gap-5 pt-2">
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
                <div className="flex flex-col gap-2.5">
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
        ) : null}
      </div>
    </main>
  );
}
