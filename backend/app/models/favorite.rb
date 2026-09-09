class Favorite < ApplicationRecord
  include SoftDeletable

  belongs_to :consumer
  # Merchant has a soft-delete default_scope, and belongs_to_required_by_default
  # (Rails 7.2+) revalidates presence on every save. Without unscoping
  # deleted_at here, a favorite whose merchant later gets soft-deleted would
  # fail every future save with "Merchant must exist" — the merchant_id
  # column itself is still required, this only lets the association keep
  # resolving to a soft-deleted merchant instead of finding none at all.
  belongs_to :merchant, -> { unscope(where: :deleted_at) }

  validates :merchant_id, uniqueness: { scope: :consumer_id }
end
