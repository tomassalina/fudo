class CreateGiftTypeEnum < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE TYPE gift_type_enum AS ENUM (
        'classic', 'gold', 'black', 'platinum'
      );
    SQL
  end

  def down
    execute "DROP TYPE gift_type_enum;"
  end
end
