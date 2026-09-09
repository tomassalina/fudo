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
// Layout below mirrors the design reference's own merchant-detail artboard —
// below 900px, `docs/design-reference/Fudo App.dc.html`'s `isDetail` branch
// (cover photo with gradient + back button, Barlow 900 name, meta/address
// lines, price + distance row, WhatsApp/Delivery pill buttons, a plain weekly
// hours list — same "Cerrado" / day-label / "HH:MM–HH:MM" conventions as that
// artboard's hours accordion, just without the collapse/expand interaction,
// since this is static SSG output); at/above 900px,
// `docs/design-reference/Fudo Customers.dc.html`'s `isDetail` branch (taller
// hero with the title overlaid on it, sticky two-column rail). See
// `MerchantDetailView`, the client component that actually picks between the
// two, for the rest of that doc comment. Then menu items grouped by section.
// The loyalty-progress tab from that same artboard is still deferred: it
// needs a loyalty_rules join this mock layer doesn't expose yet.
//
// Also carries a schema.org JSON-LD block (Restaurant/FoodEstablishment,
// depending on merchant.type — see SCHEMA_ORG_TYPE below) built from the same
// merchant + business_hours data, the structured-data half of the SEO work.

import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { MerchantViewedTracker } from "@/components/analytics/MerchantViewedTracker";
import { Header } from "@/components/layout/Header";
import { MerchantDetailView } from "@/components/features/restaurantes/MerchantDetailView";
import {
  buildOpeningHoursSpecification,
  getBusinessHoursForMerchant,
  groupBusinessHoursByDay,
} from "@/lib/data/business-hours";
import type { DayHours } from "@/lib/data/business-hours";
import { MERCHANT_COUNTRY_CODE, MERCHANT_TYPE_LABELS } from "@/lib/mock/merchants";
import { getMerchants, getMerchantById } from "@/lib/data/merchants";
import {
  getMenuItemsForMerchant,
  groupMenuItemsBySection,
} from "@/lib/data/menu-items";
import type { Merchant, MerchantType } from "@/lib/types";
import { formatPrice } from "@/lib/utils/format-price";

/** `null` for a malformed id (non-integer) or a merchant that truly doesn't
 * exist — both should 404. A backend/network failure is not caught here;
 * it propagates to ./error.tsx instead. */
async function findMerchant(id: string): Promise<Merchant | null> {
  const numericId = Number(id);
  if (!Number.isInteger(numericId)) return null;
  return getMerchantById(numericId);
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
    // Omitted (not emitted as null/NaN) when the backend gave us an
    // unparseable coordinate — parseCoordinate (lib/api/merchants.ts) returns
    // NaN for that case, and JSON.stringify would silently turn it into
    // `null`, publishing invalid GeoCoordinates JSON-LD.
    ...(Number.isFinite(merchant.latitude) && Number.isFinite(merchant.longitude)
      ? {
          geo: {
            "@type": "GeoCoordinates",
            latitude: merchant.latitude,
            longitude: merchant.longitude,
          },
        }
      : {}),
    ...(merchant.cover_image_url ? { image: merchant.cover_image_url } : {}),
    ...(priceRange ? { priceRange } : {}),
    ...(openingHoursSpecification.length > 0
      ? { openingHoursSpecification }
      : {}),
  };
}

export async function generateStaticParams() {
  try {
    const merchants = await getMerchants();
    return merchants.map((merchant) => ({ id: String(merchant.id) }));
  } catch {
    // Real backend unreachable at build time (NEXT_PUBLIC_API_BASE_URL set
    // but pointing nowhere/nothing up yet). Skip static pre-generation
    // instead of failing the whole build — pages still render on demand at
    // request time (Next's default dynamicParams behavior). The mock
    // branch above never throws, so this never triggers today.
    return [];
  }
}

export async function generateMetadata({
  params,
}: PageProps<"/restaurantes/[id]">): Promise<Metadata> {
  const { id } = await params;
  const merchant = await findMerchant(id);

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
  const merchant = await findMerchant(id);

  if (!merchant) {
    notFound();
  }

  const priceRange = formatPriceRange(merchant);
  const menuGroups = groupMenuItemsBySection(
    await getMenuItemsForMerchant(merchant.id),
  );
  const businessHours = await getBusinessHoursForMerchant(merchant.id);
  const weekHours = groupBusinessHoursByDay(businessHours);
  const jsonLd = buildJsonLd(merchant, weekHours);

  return (
    <main className="flex flex-1 flex-col">
      <Header />
      <MerchantViewedTracker merchantId={merchant.id} merchantType={merchant.type} />
      {/* Structured data for search engines — static, server-derived JSON, no user input involved. */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <MerchantDetailView
        merchant={merchant}
        priceRange={priceRange}
        weekHours={weekHours}
        menuGroups={menuGroups}
      />
    </main>
  );
}
