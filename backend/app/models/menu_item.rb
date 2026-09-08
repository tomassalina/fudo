class MenuItem < ApplicationRecord
  enum :currency, { usd: "usd", ars: "ars" }

  belongs_to :merchant

  has_many :menu_items_tags, dependent: :destroy
  has_many :tags, through: :menu_items_tags

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
end
