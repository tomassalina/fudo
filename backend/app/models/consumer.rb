# National ID (`dni`) is stored encrypted at rest via Lockbox
# (`dni_encrypted`) with a separate blind index (`dni_bidx`) for equality
# lookups/uniqueness, since it can't be queried directly once encrypted.
# See config/initializers/lockbox.rb for the master keys wiring.
class Consumer < ApplicationRecord
  has_encrypted :dni, encrypted_attribute: "dni_encrypted"
  blind_index :dni

  # visits, favorites, search_histories, and gifts carry their own
  # deleted_at/deleted_by columns (see db/structure.sql: "no hard deletes").
  # Cascading a real DELETE onto them via dependent: :destroy would bypass
  # that soft-delete convention, so a consumer with any of those still
  # attached must be handled explicitly (soft-deleted) instead of destroyed.
  has_many :visits, dependent: :restrict_with_error
  has_many :favorites, dependent: :restrict_with_error
  has_many :search_histories, dependent: :restrict_with_error
  has_many :sent_gifts, class_name: "Gift", foreign_key: :sender_consumer_id, inverse_of: :sender, dependent: :restrict_with_error

  # visit_summaries and consumer_settings have no soft-delete columns of
  # their own — they're derived/config rows, so hard-deleting them alongside
  # their consumer doesn't violate the schema's convention.
  has_many :visit_summaries, dependent: :destroy
  has_one :consumer_setting, dependent: :destroy

  # nullify (not destroy): a gift a consumer received keeps existing — the
  # row already supports a null recipient_consumer_id for gifts sent to a
  # phone number before the recipient ever signs up — so detaching it here
  # doesn't hard-delete anything either.
  has_many :received_gifts, class_name: "Gift", foreign_key: :recipient_consumer_id, inverse_of: :recipient, dependent: :nullify

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :password_hash, presence: true
  validates :dni, presence: true, uniqueness: true
end
