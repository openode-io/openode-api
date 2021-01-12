class AddIndexSubscriptionUserId < ActiveRecord::Migration[6.0]
  def change
    add_index(:subscriptions, [:user_id])
  end
end
