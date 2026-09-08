class MenuItemsTag < ApplicationRecord
  belongs_to :menu_item
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :menu_item_id }
end
