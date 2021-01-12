class AddUniqueSubscriptionIdToSubscriptions < ActiveRecord::Migration[6.0]
  def change
    add_index :subscriptions, :subscription_id, unique: true
  end
end
