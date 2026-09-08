class CreateMerchants < ActiveRecord::Migration[8.1]
  def change
    create_table :merchants do |t|
      t.string :name, limit: 200, null: false
      t.column :type, :merchant_type_enum, null: false
      t.string :address, limit: 255, null: false
      t.string :country, limit: 100, null: false
      t.string :state, limit: 100, null: false
      t.string :city, limit: 100, null: false
      t.string :neighborhood, limit: 100
      t.string :zip_code, limit: 20
      t.decimal :latitude, precision: 9, scale: 6, null: false
      t.decimal :longitude, precision: 9, scale: 6, null: false
      t.text :cover_image_url
      t.string :whatsapp_number, limit: 30
      t.text :delivery_url
      t.decimal :price_per_person_min, precision: 10, scale: 2
      t.decimal :price_per_person_max, precision: 10, scale: 2

      t.column :created_at, :timestamptz, null: false, default: -> { "now()" }
      t.uuid :created_by, null: false
      t.column :updated_at, :timestamptz, null: false, default: -> { "now()" }
      t.uuid :updated_by
      t.column :deleted_at, :timestamptz
      t.uuid :deleted_by
    end

    add_index :merchants, [:latitude, :longitude], name: "idx_merchants_geo"
    add_index :merchants, :type, name: "idx_merchants_type"
    add_index :merchants, :neighborhood, name: "idx_merchants_neighborhood"
  end
end
