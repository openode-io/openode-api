class AddIsSubscriptionToOrders < ActiveRecord::Migration[6.0]
  def change
    add_column :orders, :is_subscription, :boolean, default: false
  end
end
