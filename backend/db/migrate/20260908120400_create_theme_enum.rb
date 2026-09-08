class CreateThemeEnum < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE TYPE theme_enum AS ENUM (
        'light', 'dark', 'system'
      );
    SQL
  end

  def down
    execute "DROP TYPE theme_enum;"
  end
end
