class CreateMerchantsTags < ActiveRecord::Migration[8.1]
  def change
    create_table :merchants_tags do |t|
      t.bigint :merchant_id, null: false
      t.bigint :tag_id, null: false
    end

    add_foreign_key :merchants_tags, :merchants
    add_foreign_key :merchants_tags, :tags
    add_index :merchants_tags, [:merchant_id, :tag_id], unique: true
  end
end
