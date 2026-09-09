# Intentionally no uniqueness validation on (merchant_id, day_of_week): a
# merchant can have multiple shifts on the same day (e.g. lunch 12:00-15:30
# and dinner 20:00-00:30 as two separate rows) — see db/structure.sql.
class BusinessHour < ApplicationRecord
  enum :day_of_week, {
    monday: "monday",
    tuesday: "tuesday",
    wednesday: "wednesday",
    thursday: "thursday",
    friday: "friday",
    saturday: "saturday",
    sunday: "sunday"
  }

  # Merchant has a soft-delete default_scope, and belongs_to_required_by_default
  # (Rails 7.2+) revalidates presence on every save. Without unscoping
  # deleted_at here, a business hour whose merchant later gets soft-deleted
  # would fail every future save with "Merchant must exist" — the
  # merchant_id column itself is still required, this only lets the
  # association keep resolving to a soft-deleted merchant instead of
  # finding none at all.
  belongs_to :merchant, -> { unscope(where: :deleted_at) }

  validates :day_of_week, presence: true
end
