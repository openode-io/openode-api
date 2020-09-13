class CreateAddons < ActiveRecord::Migration[6.0]
  def change
    create_table :addons do |t|
      t.string :name
      t.string :category
      t.text :obj

      t.timestamps
    end
  end
end
