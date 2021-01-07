class AddIndexSubscriptionWebsiteWebsiteId < ActiveRecord::Migration[6.0]
  def change
    add_index :subscription_websites, :website_id
  end
end
