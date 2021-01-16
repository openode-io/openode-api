class AddSubscriptionExpiresAt < ActiveRecord::Migration[6.0]
  def change
    add_column :subscriptions, :expires_at, :datetime, precision: 6, null: true
  end
end
