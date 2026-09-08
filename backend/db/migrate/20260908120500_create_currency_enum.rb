class CreateCurrencyEnum < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE TYPE currency_enum AS ENUM (
        'usd', 'ars'
      );
    SQL
  end

  def down
    execute "DROP TYPE currency_enum;"
  end
end
