class CreateGifts < ActiveRecord::Migration[8.1]
  def change
    create_table :gifts do |t|
      t.uuid :sender_consumer_id, null: false
      t.uuid :recipient_consumer_id
      t.column :type, :gift_type_enum, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :recipient_phone, limit: 30, null: false
      t.text :message
      t.column :expires_at, :timestamptz, null: false
      t.column :status, :gift_status_enum, null: false, default: "pending"
      t.column :status_updated_at, :timestamptz

      t.column :created_at, :timestamptz, null: false, default: -> { "now()" }
      t.uuid :created_by, null: false
      t.column :updated_at, :timestamptz, null: false, default: -> { "now()" }
      t.uuid :updated_by
      t.column :deleted_at, :timestamptz
      t.uuid :deleted_by
    end

    add_foreign_key :gifts, :consumers, column: :sender_consumer_id
    add_foreign_key :gifts, :consumers, column: :recipient_consumer_id
  end
end
