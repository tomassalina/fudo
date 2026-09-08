class CreateLoyaltyRules < ActiveRecord::Migration[8.1]
  def change
    create_table :loyalty_rules do |t|
      t.bigint :merchant_id, null: false
      t.integer :visits_required, null: false
      t.column :reward_type, :reward_type_enum, null: false
      t.text :reward_description, null: false
      t.boolean :is_permanent, null: false, default: false

      t.column :created_at, :timestamptz, null: false, default: -> { "now()" }
      t.uuid :created_by, null: false
      t.column :updated_at, :timestamptz, null: false, default: -> { "now()" }
      t.uuid :updated_by
      t.column :deleted_at, :timestamptz
      t.uuid :deleted_by
    end

    add_foreign_key :loyalty_rules, :merchants
  end
end
