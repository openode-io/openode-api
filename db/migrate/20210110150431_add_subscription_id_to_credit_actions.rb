class AddSubscriptionIdToCreditActions < ActiveRecord::Migration[6.0]
  def change
    add_column :credit_actions, :subscription_id, :bigint
  end
end
