class CreateRequestOrders < ActiveRecord::Migration[6.1]
  def change
    create_table :request_orders do |t|
      t.references :user
      t.float :amount
      t.string :provider_type

      t.timestamps
    end
  end
end
