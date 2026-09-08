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
  neighborhood: string;
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
