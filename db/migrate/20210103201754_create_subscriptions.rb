class CreateSubscriptions < ActiveRecord::Migration[6.0]
  def change
    create_table :subscriptions do |t|
      t.integer :user_id
      t.integer :quantity
      t.boolean :active
      t.string :subscription_id

      t.timestamps
    end
  end
end
