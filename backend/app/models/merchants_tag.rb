class MerchantsTag < ApplicationRecord
  belongs_to :merchant
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :merchant_id }
end
