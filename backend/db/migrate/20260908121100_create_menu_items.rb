class CreateMenuItems < ActiveRecord::Migration[8.1]
  def change
    create_table :menu_items do |t|
      t.bigint :merchant_id, null: false
      t.string :name, limit: 200, null: false
      t.text :description
      t.decimal :price, precision: 10, scale: 2, null: false
      t.column :currency, :currency_enum, null: false
      t.string :section, limit: 100
      t.text :image_url
      t.boolean :active, null: false, default: true

      t.column :created_at, :timestamptz, null: false, default: -> { "now()" }
      t.uuid :created_by, null: false
      t.column :updated_at, :timestamptz, null: false, default: -> { "now()" }
      t.uuid :updated_by
      t.column :deleted_at, :timestamptz
      t.uuid :deleted_by
    end

    add_foreign_key :menu_items, :merchants
    add_index :menu_items, :merchant_id, name: "idx_menu_items_merchant_id"
  end
end
