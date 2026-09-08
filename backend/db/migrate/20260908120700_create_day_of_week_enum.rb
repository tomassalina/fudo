class CreateDayOfWeekEnum < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE TYPE day_of_week_enum AS ENUM (
        'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
      );
    SQL
  end

  def down
    execute "DROP TYPE day_of_week_enum;"
  end
end
