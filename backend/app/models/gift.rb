class Gift < ApplicationRecord
  # The `type` column is a native Postgres enum (gift_type_enum), not a Rails
  # STI discriminator. Disable STI so `type=` behaves like any other
  # attribute.
  self.inheritance_column = :_type_disabled

  enum :type, { classic: "classic", gold: "gold", black: "black", platinum: "platinum" }
  enum :status, { pending: "pending", redeemed: "redeemed", expired: "expired", cancelled: "cancelled" }

  belongs_to :sender, class_name: "Consumer", foreign_key: :sender_consumer_id, inverse_of: :sent_gifts
  belongs_to :recipient, class_name: "Consumer", foreign_key: :recipient_consumer_id, inverse_of: :received_gifts, optional: true

  validates :type, presence: true
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :recipient_phone, presence: true
  validates :expires_at, presence: true
  validates :status, presence: true
end
