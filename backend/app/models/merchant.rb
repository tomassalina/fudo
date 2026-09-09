class Merchant < ApplicationRecord
  include SoftDeletable

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

  # Shared filtering logic used by both Api::V1::MerchantsController#index
  # (raw query params) and Api::V1::SearchController#create (filters parsed
  # from natural language via SearchQueryParser). Callers own parsing their
  # own input into this shape — in particular, `tags` here is expected to
  # already be an array of tag names, not a comma-separated string.
  def self.search(neighborhood: nil, type: nil, tags: [], price_per_person: nil)
    scope = all
    scope = filter_by_neighborhood(scope, neighborhood)
    # `type` is intentionally an exact match, unlike neighborhood/tags: it's a
    # Rails enum constrained to a fixed set of lowercase keys (see the `enum`
    # declaration above), and both callers (Api::V1::MerchantsController and
    # SearchQueryParser's response_schema, which restricts Gemini's output to
    # Merchant.types.keys) already guarantee it arrives pre-normalized. There
    # is no untrusted-casing source for it the way there is for
    # neighborhood/tags free text.
    scope = scope.where(type: type) if type.present?
    scope = filter_by_tags(scope, tags)
    scope = filter_by_price_per_person(scope, price_per_person)
    scope
  end

  def self.filter_by_neighborhood(scope, neighborhood)
    return scope if neighborhood.blank?

    # Case-insensitive on purpose, same rationale as filter_by_tags below:
    # neighborhood can come from Gemini's parsed output (prompted to copy the
    # user's text "exactly as written", casing included — see
    # SearchQueryParser::SYSTEM_INSTRUCTION), a manually-typed URL param
    # (/buscar?hood=palermo), or any future seed data using a different
    # casing convention. An exact `where(neighborhood: ...)` match silently
    # returned zero results whenever the caller's casing didn't match the
    # DB's stored casing exactly (confirmed live: `hood=palermo` returned
    # nothing while `hood=Palermo` worked, for the same seeded "Palermo"
    # rows) — this is an architectural gotcha, not a one-off input error, so
    # the fix belongs at the query level rather than expecting every caller
    # to normalize first.
    scope.where("LOWER(neighborhood) = ?", neighborhood.downcase)
  end
  private_class_method :filter_by_neighborhood

  def self.filter_by_tags(scope, tags)
    tag_names = Array(tags).map(&:to_s).map(&:strip).reject(&:blank?)
    return scope if tag_names.empty?

    # Case-insensitive on purpose: tags here can come straight from Gemini's
    # parsed output (see SearchQueryParser), which is prompted to use
    # lowercase tags but never guaranteed to — an exact `where(name: ...)`
    # match would silently drop matches on any casing difference.
    scope.joins(:tags).where("LOWER(tags.name) IN (?)", tag_names.map(&:downcase)).distinct
  end
  private_class_method :filter_by_tags

  def self.filter_by_price_per_person(scope, price_per_person)
    return scope if price_per_person.blank?

    scope.where(
      "price_per_person_min <= :price AND price_per_person_max >= :price",
      price: price_per_person
    )
  end
  private_class_method :filter_by_price_per_person
end
