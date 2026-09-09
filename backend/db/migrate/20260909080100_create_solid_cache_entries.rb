# Creates the solid_cache_entries table in the app's primary database
# (single-database Solid Cache setup — see config/cache.yml). Schema
# matches the solid_cache gem's own install template (cache_schema.rb /
# cache_structure.postgresql.sql), reproduced here as a regular migration
# so it's captured by db/structure.sql like every other table instead of
# a separate cache database/structure file.
class CreateSolidCacheEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :solid_cache_entries do |t|
      t.binary :key, limit: 1024, null: false
      t.binary :value, limit: 536_870_912, null: false
      t.datetime :created_at, null: false
      t.integer :key_hash, limit: 8, null: false
      t.integer :byte_size, limit: 4, null: false
    end

    add_index :solid_cache_entries, :byte_size
    add_index :solid_cache_entries, [ :key_hash, :byte_size ]
    add_index :solid_cache_entries, :key_hash, unique: true
  end
end
