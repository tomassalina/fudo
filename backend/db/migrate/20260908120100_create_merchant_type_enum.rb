class CreateMerchantTypeEnum < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE TYPE merchant_type_enum AS ENUM (
        'restaurant', 'cafe', 'bar', 'dark_kitchen', 'pizzeria', 'brewery', 'food_truck', 'other'
      );
    SQL
  end

  def down
    execute "DROP TYPE merchant_type_enum;"
  end
end
