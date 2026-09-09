// Data types for the Fudo Consumers sub-platform.
//
// These now mirror the real backend schema (backend/db/structure.sql, see
// docs/design-reference/fudo-design-seed.json for the exported fixture data)
// field-for-field where practical, per PLAN.md Fase 2: the web mock layer
// should use "los mismos nombres y tipos de columnas" the real API will
// return, so swapping in a real fetch later (Fase 4) doesn't mean renaming
// every field. Audit/soft-delete columns (created_at/by, updated_at/by,
// deleted_at/by) are intentionally omitted — not needed by the UI.

export type MerchantType =
  | "restaurant"
  | "cafe"
  | "bar"
  | "brewery"
  | "pizzeria"
  | "food_truck"
  | "dark_kitchen"
  | "other";

export interface Merchant {
  id: number;
  name: string;
  type: MerchantType;
  address: string;
  country: string;
  state: string;
  /** Nullable in the schema (backend/db/structure.sql: no NOT NULL). */
  neighborhood?: string;
  city: string;
  latitude: number;
  longitude: number;
  /** Nullable in the schema (backend/db/structure.sql: no NOT NULL). */
  cover_image_url?: string;
  /** Nullable in the schema. */
  whatsapp_number?: string;
  delivery_url?: string;
  /** ARS, per person. Nullable in the schema — hide the price range when either is missing. */
  price_per_person_min?: number;
  price_per_person_max?: number;

  /**
   * Derived for this mock/UI layer only — flattens the real `merchants_tags`
   * join (attribute tags like "vegano", "delivery"), not a raw column.
   */
  tags: string[];
  /** Derived for this mock/UI layer only — name of a representative active menu item. */
  topDish?: string;
  /** Derived for this mock/UI layer only — the merchant's easiest loyalty_rules tier, pre-formatted for the card. */
  rewardTeaser?: string;
  /**
   * Derived for this mock/UI layer only — great-circle distance in km from a
   * fixed simulated user location (there's no real geolocation yet, per the
   * PRD). Not a backend column; the real API will likely compute this
   * server-side from the user's actual position.
   */
  distanceKm: number;
}

export interface MenuItem {
  id: number;
  merchant_id: number;
  name: string;
  description?: string;
  price: number;
  currency: "ars" | "usd";
  section: string;
  image_url?: string;
  active: boolean;
}

export type DayOfWeek =
  | "monday"
  | "tuesday"
  | "wednesday"
  | "thursday"
  | "friday"
  | "saturday"
  | "sunday";

export interface BusinessHours {
  id: number;
  merchant_id: number;
  day_of_week: DayOfWeek;
  /** "HH:MM:SS", null when `closed` is true. */
  opens_at: string | null;
  /** "HH:MM:SS", null when `closed` is true. May be earlier than opens_at — the shift crosses midnight. */
  closes_at: string | null;
  closed: boolean;
}

/** Mirrors `public.reward_type_enum` (backend/db/structure.sql). */
export type RewardType = "discount_percent" | "free_item" | "cashback" | "other";

/**
 * Mirrors `loyalty_rules` (backend/db/structure.sql) field-for-field. There
 * is no live endpoint for this table yet (see lib/api/README.md's "Endpoint
 * coverage" table — only merchants/menu_items are confirmed), so
 * lib/mock/loyalty.ts derives a plausible ladder per merchant instead of
 * fetching real rows. Real per-consumer visit counts also don't exist here
 * (see lib/api/README.md's "Out of scope: auth" — visit history lives in the
 * mobile app), so `getLoyaltyProgress` below renders honest mock progress
 * once `useSession()` (a real, mocked-login session — see
 * lib/session/session-provider.tsx) reports a logged-in consumer, and the
 * logged-out copy otherwise; the real `visits` table still needs to land
 * before the visit counts themselves are real.
 */
export interface LoyaltyRule {
  id: number;
  merchant_id: number;
  visits_required: number;
  reward_type: RewardType;
  reward_description: string;
  is_permanent: boolean;
}

/** One rung of the visit-progress ladder rendered on the merchant detail page. */
export interface LoyaltyStep {
  visitNumber: number;
  rule: LoyaltyRule | null;
  /** The consumer has already reached this many visits. */
  done: boolean;
  /** The consumer is exactly at this step right now. */
  isHere: boolean;
  /** This is the next reward the consumer hasn't reached yet. */
  isNext: boolean;
}

/** Fully-derived loyalty state for one merchant, ready to render — see
 * `getLoyaltyProgress` in lib/mock/loyalty.ts for both the logged-in and
 * logged-out copy variants this carries. */
export interface LoyaltyProgress {
  authenticated: boolean;
  visits: number;
  steps: LoyaltyStep[];
  tierLabel: string;
  headline: string;
  sub: string;
  note: string;
}

/** One dish result for the /buscar "Platos" mode — a menu item plus the
 * merchant that serves it, since dish cards render both (see DishCard). */
export interface DishSearchResult {
  item: MenuItem;
  merchant: Merchant;
}
