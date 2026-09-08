class CreateSearchHistory < ActiveRecord::Migration[8.1]
  def change
    create_table :search_history do |t|
      t.uuid :consumer_id, null: false
      t.text :query_text, null: false
      t.jsonb :structured_output

      t.column :created_at, :timestamptz, null: false, default: -> { "now()" }
      t.uuid :created_by, null: false
      t.column :updated_at, :timestamptz, null: false, default: -> { "now()" }
      t.uuid :updated_by
      t.column :deleted_at, :timestamptz
      t.uuid :deleted_by
    end

    add_foreign_key :search_history, :consumers
    add_index :search_history, :consumer_id, name: "idx_search_history_consumer_id"
  end
end
