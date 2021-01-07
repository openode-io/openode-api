class CreateSubscriptionWebsites < ActiveRecord::Migration[6.0]
  def change
    create_table :subscription_websites do |t|
      t.integer :website_id
      t.references :subscription, null: false, foreign_key: true
      t.integer :quantity

      t.timestamps
    end
  end
end
