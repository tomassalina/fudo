class CreateVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :visits do |t|
      t.uuid :consumer_id, null: false
      t.bigint :merchant_id, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.boolean :reward_applied, null: false, default: false
      t.text :reward_description_snapshot
      t.column :visited_at, :timestamptz, null: false

      t.column :created_at, :timestamptz, null: false, default: -> { "now()" }
      t.uuid :created_by, null: false
      t.column :updated_at, :timestamptz, null: false, default: -> { "now()" }
      t.uuid :updated_by
      t.column :deleted_at, :timestamptz
      t.uuid :deleted_by
    end

    add_foreign_key :visits, :consumers
    add_foreign_key :visits, :merchants
    add_index :visits, [:consumer_id, :merchant_id], name: "idx_visits_consumer_merchant"
    add_index :visits, :visited_at, name: "idx_visits_visited_at"
  end
end
