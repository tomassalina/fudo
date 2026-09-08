# The table is named `search_history` (singular) rather than the Rails-default
# pluralized `search_histories`, so the table name is set explicitly.
class SearchHistory < ApplicationRecord
  self.table_name = "search_history"

  belongs_to :consumer

  validates :query_text, presence: true
end
