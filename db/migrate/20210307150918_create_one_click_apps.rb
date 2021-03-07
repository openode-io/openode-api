class CreateOneClickApps < ActiveRecord::Migration[6.1]
  def change
    create_table :one_click_apps do |t|
      t.string :name
      t.text :prepare, size: :medium
      t.text :config, size: :medium
      t.text :dockerfile, size: :medium

      t.timestamps
    end

    add_index :one_click_apps, :name, unique: true
  end
end
