class AddIndexesViewedNotifications < ActiveRecord::Migration[6.0]
  def change
    add_index :viewed_notifications, %i[user_id notification_id]
  end
end
