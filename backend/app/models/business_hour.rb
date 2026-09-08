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

  belongs_to :merchant

  validates :day_of_week, presence: true
end
