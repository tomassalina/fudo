class VisitSummary < ApplicationRecord
  belongs_to :consumer
  belongs_to :merchant

  validates :count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :consumer_id, uniqueness: { scope: :merchant_id }
end
