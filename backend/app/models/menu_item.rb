class MenuItem < ApplicationRecord
  include SoftDeletable

  enum :currency, { usd: "usd", ars: "ars" }

  # Merchant has a soft-delete default_scope, and belongs_to_required_by_default
  # (Rails 7.2+) revalidates presence on every save. Without unscoping
  # deleted_at here, a menu item whose merchant later gets soft-deleted
  # would fail every future save with "Merchant must exist" — the
  # merchant_id column itself is still required, this only lets the
  # association keep resolving to a soft-deleted merchant instead of
  # finding none at all.
  belongs_to :merchant, -> { unscope(where: :deleted_at) }

  has_many :menu_items_tags, dependent: :destroy
  has_many :tags, through: :menu_items_tags

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
end
