class Merchant < ApplicationRecord
  # The `type` column is a native Postgres enum (merchant_type_enum), not a
  # Rails STI discriminator. Disable STI so `type=` behaves like any other
  # attribute.
  self.inheritance_column = :_type_disabled

  enum :type, {
    restaurant: "restaurant",
    cafe: "cafe",
    bar: "bar",
    dark_kitchen: "dark_kitchen",
    pizzeria: "pizzeria",
    brewery: "brewery",
    food_truck: "food_truck",
    other: "other"
  }

  # menu_items, loyalty_rules, visits, and favorites carry their own
  # deleted_at/deleted_by columns (see db/structure.sql: "no hard deletes").
  # Cascading a real DELETE onto them via dependent: :destroy would bypass
  # that soft-delete convention, so a merchant with any of those still
  # attached must be handled explicitly (soft-deleted) instead of destroyed.
  has_many :menu_items, dependent: :restrict_with_error
  has_many :loyalty_rules, dependent: :restrict_with_error
  has_many :visits, dependent: :restrict_with_error
  has_many :favorites, dependent: :restrict_with_error

  # merchants_tags, business_hours, and visit_summaries have no soft-delete
  # columns of their own — they're pure join/derived rows, so hard-deleting
  # them alongside their merchant doesn't violate the schema's convention.
  has_many :merchants_tags, dependent: :destroy
  has_many :tags, through: :merchants_tags
  has_many :business_hours, dependent: :destroy
  has_many :visit_summaries, dependent: :destroy

  validates :name, presence: true
  validates :type, presence: true
  validates :address, presence: true
  validates :country, presence: true
  validates :state, presence: true
  validates :city, presence: true
  validates :latitude, presence: true
  validates :longitude, presence: true
end
