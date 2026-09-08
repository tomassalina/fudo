class ConsumerSetting < ApplicationRecord
  enum :theme, { light: "light", dark: "dark", system: "system" }

  belongs_to :consumer

  validates :consumer_id, uniqueness: true
  validates :theme, presence: true
end
