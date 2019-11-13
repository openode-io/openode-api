class CreateSystemSettings < ActiveRecord::Migration[6.0]
  def change
    create_table :system_settings do |t|
      t.string :name
      t.text :content

      t.timestamps
    end
  end
end
