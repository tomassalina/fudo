class CreateRewardTypeEnum < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE TYPE reward_type_enum AS ENUM (
        'discount_percent', 'free_item', 'cashback', 'other'
      );
    SQL
  end

  def down
    execute "DROP TYPE reward_type_enum;"
  end
end
