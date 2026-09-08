-- Fudo Consumers — PostgreSQL schema (source of truth)
-- See docs/database-schema.drawio / docs/database-schema.png for the visual diagram.
-- 14 tables + 7 enums. Soft-delete convention: deleted_at/deleted_by nullable, no hard deletes.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- ENUMS
-- ============================================================================

CREATE TYPE merchant_type_enum AS ENUM (
  'restaurant', 'cafe', 'bar', 'dark_kitchen', 'pizzeria', 'brewery', 'food_truck', 'other'
);

CREATE TYPE gift_type_enum AS ENUM (
  'classic', 'gold', 'black', 'platinum'
);

CREATE TYPE gift_status_enum AS ENUM (
  'pending', 'redeemed', 'expired', 'cancelled'
);

CREATE TYPE theme_enum AS ENUM (
  'light', 'dark', 'system'
);

CREATE TYPE currency_enum AS ENUM (
  'usd', 'ars'
);

CREATE TYPE reward_type_enum AS ENUM (
  'discount_percent', 'free_item', 'cashback', 'other'
);

CREATE TYPE day_of_week_enum AS ENUM (
  'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
);

-- ============================================================================
-- TAGS
-- ============================================================================

CREATE TABLE tags (
  id          BIGSERIAL PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by  UUID NOT NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by  UUID,
  deleted_at  TIMESTAMPTZ,
  deleted_by  UUID
);

-- ============================================================================
-- MERCHANTS
-- ============================================================================

CREATE TABLE merchants (
  id                     BIGSERIAL PRIMARY KEY,
  name                   VARCHAR(200) NOT NULL,
  type                   merchant_type_enum NOT NULL,
  address                VARCHAR(255) NOT NULL,
  country                VARCHAR(100) NOT NULL,
  state                  VARCHAR(100) NOT NULL,
  city                   VARCHAR(100) NOT NULL,
  neighborhood           VARCHAR(100),
  zip_code               VARCHAR(20),
  latitude               NUMERIC(9,6) NOT NULL,
  longitude              NUMERIC(9,6) NOT NULL,
  cover_image_url        TEXT,
  whatsapp_number        VARCHAR(30),
  delivery_url           TEXT,
  price_per_person_min   NUMERIC(10,2),
  price_per_person_max   NUMERIC(10,2),
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by             UUID NOT NULL,
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by             UUID,
  deleted_at             TIMESTAMPTZ,
  deleted_by             UUID
);

CREATE INDEX idx_merchants_geo ON merchants (latitude, longitude);
CREATE INDEX idx_merchants_type ON merchants (type);
CREATE INDEX idx_merchants_neighborhood ON merchants (neighborhood);

-- ============================================================================
-- CONSUMERS
-- ============================================================================

CREATE TABLE consumers (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name     VARCHAR(100) NOT NULL,
  last_name      VARCHAR(100) NOT NULL,
  email          VARCHAR(255) NOT NULL UNIQUE,
  password_hash  VARCHAR(255) NOT NULL,
  dni_encrypted  TEXT NOT NULL,
  dni_bidx       VARCHAR(255) NOT NULL,
  phone          VARCHAR(30),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by     UUID NOT NULL,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by     UUID,
  deleted_at     TIMESTAMPTZ,
  deleted_by     UUID
);

CREATE UNIQUE INDEX idx_consumers_dni_bidx ON consumers (dni_bidx);

-- ============================================================================
-- MENU ITEMS
-- ============================================================================

CREATE TABLE menu_items (
  id           BIGSERIAL PRIMARY KEY,
  merchant_id  BIGINT NOT NULL REFERENCES merchants (id),
  name         VARCHAR(200) NOT NULL,
  description  TEXT,
  price        NUMERIC(10,2) NOT NULL,
  currency     currency_enum NOT NULL,
  section      VARCHAR(100),
  image_url    TEXT,
  active       BOOLEAN NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by   UUID NOT NULL,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by   UUID,
  deleted_at   TIMESTAMPTZ,
  deleted_by   UUID
);

CREATE INDEX idx_menu_items_merchant_id ON menu_items (merchant_id);

-- ============================================================================
-- TAG JOIN TABLES
-- ============================================================================

CREATE TABLE merchants_tags (
  id           BIGSERIAL PRIMARY KEY,
  merchant_id  BIGINT NOT NULL REFERENCES merchants (id),
  tag_id       BIGINT NOT NULL REFERENCES tags (id),
  UNIQUE (merchant_id, tag_id)
);

CREATE TABLE menu_items_tags (
  id            BIGSERIAL PRIMARY KEY,
  menu_item_id  BIGINT NOT NULL REFERENCES menu_items (id),
  tag_id        BIGINT NOT NULL REFERENCES tags (id),
  UNIQUE (menu_item_id, tag_id)
);

-- ============================================================================
-- LOYALTY: VISIT SUMMARIES, VISITS, LOYALTY RULES
-- ============================================================================

CREATE TABLE visit_summaries (
  id             BIGSERIAL PRIMARY KEY,
  consumer_id    UUID NOT NULL REFERENCES consumers (id),
  merchant_id    BIGINT NOT NULL REFERENCES merchants (id),
  count          INTEGER NOT NULL DEFAULT 0,
  current_tier   VARCHAR(100),
  last_visit_at  TIMESTAMPTZ,
  UNIQUE (merchant_id, consumer_id)
);

CREATE TABLE visits (
  id                          BIGSERIAL PRIMARY KEY,
  consumer_id                 UUID NOT NULL REFERENCES consumers (id),
  merchant_id                 BIGINT NOT NULL REFERENCES merchants (id),
  amount                      NUMERIC(10,2) NOT NULL,
  reward_applied              BOOLEAN NOT NULL DEFAULT false,
  reward_description_snapshot TEXT,
  visited_at                  TIMESTAMPTZ NOT NULL,
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by                  UUID NOT NULL,
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by                  UUID,
  deleted_at                  TIMESTAMPTZ,
  deleted_by                  UUID
);

CREATE INDEX idx_visits_consumer_merchant ON visits (consumer_id, merchant_id);
CREATE INDEX idx_visits_visited_at ON visits (visited_at);

CREATE TABLE loyalty_rules (
  id                 BIGSERIAL PRIMARY KEY,
  merchant_id        BIGINT NOT NULL REFERENCES merchants (id),
  visits_required    INTEGER NOT NULL,
  reward_type        reward_type_enum NOT NULL,
  reward_description TEXT NOT NULL,
  is_permanent       BOOLEAN NOT NULL DEFAULT false,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by         UUID NOT NULL,
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by         UUID,
  deleted_at         TIMESTAMPTZ,
  deleted_by         UUID
);

-- ============================================================================
-- BUSINESS HOURS
-- No unique index on (merchant_id, day_of_week) on purpose: a merchant can
-- have multiple shifts the same day (e.g. lunch 12:00-15:30, dinner 20:00-00:30).
-- ============================================================================

CREATE TABLE business_hours (
  id           BIGSERIAL PRIMARY KEY,
  merchant_id  BIGINT NOT NULL REFERENCES merchants (id),
  day_of_week  day_of_week_enum NOT NULL,
  opens_at     TIME,
  closes_at    TIME,
  closed       BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX idx_business_hours_merchant_id ON business_hours (merchant_id);

-- ============================================================================
-- FAVORITES
-- ============================================================================

CREATE TABLE favorites (
  id           BIGSERIAL PRIMARY KEY,
  consumer_id  UUID NOT NULL REFERENCES consumers (id),
  merchant_id  BIGINT NOT NULL REFERENCES merchants (id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by   UUID NOT NULL,
  deleted_at   TIMESTAMPTZ,
  deleted_by   UUID,
  UNIQUE (consumer_id, merchant_id)
);

-- ============================================================================
-- GIFTS
-- ============================================================================

CREATE TABLE gifts (
  id                     BIGSERIAL PRIMARY KEY,
  sender_consumer_id     UUID NOT NULL REFERENCES consumers (id),
  recipient_consumer_id  UUID REFERENCES consumers (id),
  type                   gift_type_enum NOT NULL,
  amount                 NUMERIC(10,2) NOT NULL,
  recipient_phone        VARCHAR(30) NOT NULL,
  message                TEXT,
  expires_at             TIMESTAMPTZ NOT NULL,
  status                 gift_status_enum NOT NULL DEFAULT 'pending',
  status_updated_at      TIMESTAMPTZ,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by             UUID NOT NULL,
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by             UUID,
  deleted_at             TIMESTAMPTZ,
  deleted_by             UUID
);

-- ============================================================================
-- CONSUMER SETTINGS (1:1 with consumers)
-- ============================================================================

CREATE TABLE consumer_settings (
  id                     BIGSERIAL PRIMARY KEY,
  consumer_id            UUID NOT NULL UNIQUE REFERENCES consumers (id),
  theme                  theme_enum NOT NULL DEFAULT 'system',
  notifications_enabled  BOOLEAN NOT NULL DEFAULT true,
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by             UUID
);

-- ============================================================================
-- SEARCH HISTORY (AI search: free text -> structured filters)
-- ============================================================================

CREATE TABLE search_history (
  id                 BIGSERIAL PRIMARY KEY,
  consumer_id        UUID NOT NULL REFERENCES consumers (id),
  query_text         TEXT NOT NULL,
  structured_output  JSONB,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by         UUID NOT NULL,
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by         UUID,
  deleted_at         TIMESTAMPTZ,
  deleted_by         UUID
);

CREATE INDEX idx_search_history_consumer_id ON search_history (consumer_id);
