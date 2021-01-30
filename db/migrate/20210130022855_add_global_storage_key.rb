class AddGlobalStorageKey < ActiveRecord::Migration[6.0]
  def change
    add_column :global_storages, :key, :string, default: ""
  end
end
