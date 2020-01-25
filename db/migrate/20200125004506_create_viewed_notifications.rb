class CreateViewedNotifications < ActiveRecord::Migration[6.0]
  def change
    create_table :viewed_notifications do |t|
      t.references :user, null: false
      t.references :notification, null: false

      t.timestamps
    end
  end
end
