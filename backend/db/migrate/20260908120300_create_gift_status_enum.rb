class CreateGiftStatusEnum < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE TYPE gift_status_enum AS ENUM (
        'pending', 'redeemed', 'expired', 'cancelled'
      );
    SQL
  end

  def down
    execute "DROP TYPE gift_status_enum;"
  end
end
