class AddIndexSubscriptionIdToCreditActions < ActiveRecord::Migration[6.0]
  def change
    add_index :credit_actions, :subscription_id
  end
end
