# A label attachable to merchants and/or menu items (e.g. "vegano",
# "sin_tacc", "con_delivery"). Not DB-unique on `name`, so callers that want
# to avoid duplicates (e.g. seeds) should use `find_or_create_by!`.
class Tag < ApplicationRecord
  has_many :merchants_tags, dependent: :destroy
  has_many :merchants, through: :merchants_tags

  has_many :menu_items_tags, dependent: :destroy
  has_many :menu_items, through: :menu_items_tags

  validates :name, presence: true
end
