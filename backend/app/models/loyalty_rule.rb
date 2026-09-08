class LoyaltyRule < ApplicationRecord
  include SoftDeletable

  enum :reward_type, {
    discount_percent: "discount_percent",
    free_item: "free_item",
    cashback: "cashback",
    other: "other"
  }

  # Merchant has a soft-delete default_scope, and belongs_to_required_by_default
  # (Rails 7.2+) revalidates presence on every save. Without unscoping
  # deleted_at here, a loyalty rule whose merchant later gets soft-deleted
  # would fail every future save with "Merchant must exist" — the
  # merchant_id column itself is still required, this only lets the
  # association keep resolving to a soft-deleted merchant instead of
  # finding none at all.
  belongs_to :merchant, -> { unscope(where: :deleted_at) }

  validates :visits_required, presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :reward_type, presence: true
  validates :reward_description, presence: true
end
