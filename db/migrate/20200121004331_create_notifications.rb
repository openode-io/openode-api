class CreateNotifications < ActiveRecord::Migration[6.0]
  def change
    create_table :notifications do |t|
      t.string :type
      t.string :level
      t.text :content
      t.references :website, null: true

      t.timestamps
    end
  end
end
