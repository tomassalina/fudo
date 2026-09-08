class CreateConsumerSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :consumer_settings do |t|
      t.uuid :consumer_id, null: false
      t.column :theme, :theme_enum, null: false, default: "system"
      t.boolean :notifications_enabled, null: false, default: true
      t.column :updated_at, :timestamptz, null: false, default: -> { "now()" }
      t.uuid :updated_by
    end

    add_foreign_key :consumer_settings, :consumers
    add_index :consumer_settings, :consumer_id, unique: true
  end
end
