class CreateMenuItemsTags < ActiveRecord::Migration[8.1]
  def change
    create_table :menu_items_tags do |t|
      t.bigint :menu_item_id, null: false
      t.bigint :tag_id, null: false
    end

    add_foreign_key :menu_items_tags, :menu_items
    add_foreign_key :menu_items_tags, :tags
    add_index :menu_items_tags, [:menu_item_id, :tag_id], unique: true
  end
end
