class CreateConsumers < ActiveRecord::Migration[8.1]
  def change
    create_table :consumers, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :first_name, limit: 100, null: false
      t.string :last_name, limit: 100, null: false
      t.string :email, limit: 255, null: false
      t.string :password_hash, limit: 255, null: false
      t.text :dni_encrypted, null: false
      t.string :dni_bidx, limit: 255, null: false
      t.string :phone, limit: 30

      t.column :created_at, :timestamptz, null: false, default: -> { "now()" }
      t.uuid :created_by, null: false
      t.column :updated_at, :timestamptz, null: false, default: -> { "now()" }
      t.uuid :updated_by
      t.column :deleted_at, :timestamptz
      t.uuid :deleted_by
    end

    add_index :consumers, :email, unique: true
    add_index :consumers, :dni_bidx, unique: true, name: "idx_consumers_dni_bidx"
  end
end
