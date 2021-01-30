class AddIndexGlobalStorageKey < ActiveRecord::Migration[6.0]
  def change
    add_index :global_storages, :key
  end
end
