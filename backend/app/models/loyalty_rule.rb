class LoyaltyRule < ApplicationRecord
  enum :reward_type, {
    discount_percent: "discount_percent",
    free_item: "free_item",
    cashback: "cashback",
    other: "other"
  }

  belongs_to :merchant

  validates :visits_required, presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :reward_type, presence: true
  validates :reward_description, presence: true
end
