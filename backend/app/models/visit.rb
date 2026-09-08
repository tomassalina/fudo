class Visit < ApplicationRecord
  belongs_to :consumer
  belongs_to :merchant

  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :visited_at, presence: true
end
