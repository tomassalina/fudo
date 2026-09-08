class CreateVisitSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :visit_summaries do |t|
      t.uuid :consumer_id, null: false
      t.bigint :merchant_id, null: false
      t.integer :count, null: false, default: 0
      t.string :current_tier, limit: 100
      t.column :last_visit_at, :timestamptz
    end

    add_foreign_key :visit_summaries, :consumers
    add_foreign_key :visit_summaries, :merchants
    add_index :visit_summaries, [:merchant_id, :consumer_id], unique: true
  end
end
