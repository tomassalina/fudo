class Favorite < ApplicationRecord
  include SoftDeletable

  belongs_to :consumer
  belongs_to :merchant

  validates :merchant_id, uniqueness: { scope: :consumer_id }
end
