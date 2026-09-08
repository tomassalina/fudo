class CreateBusinessHours < ActiveRecord::Migration[8.1]
  def change
    create_table :business_hours do |t|
      t.bigint :merchant_id, null: false
      t.column :day_of_week, :day_of_week_enum, null: false
      t.time :opens_at
      t.time :closes_at
      t.boolean :closed, null: false, default: false
    end

    add_foreign_key :business_hours, :merchants
    add_index :business_hours, :merchant_id, name: "idx_business_hours_merchant_id"
  end
end
