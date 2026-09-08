class CreateFavorites < ActiveRecord::Migration[8.1]
  def change
    create_table :favorites do |t|
      t.uuid :consumer_id, null: false
      t.bigint :merchant_id, null: false

      t.column :created_at, :timestamptz, null: false, default: -> { "now()" }
      t.uuid :created_by, null: false
      t.column :deleted_at, :timestamptz
      t.uuid :deleted_by
    end

    add_foreign_key :favorites, :consumers
    add_foreign_key :favorites, :merchants
    add_index :favorites, [:consumer_id, :merchant_id], unique: true
  end
end
