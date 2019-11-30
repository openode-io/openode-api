class CreateGlobalStorages < ActiveRecord::Migration[6.0]
  def change
    create_table :global_storages do |t|
      t.string :type
      t.text :obj

      t.timestamps
    end
  end
end
