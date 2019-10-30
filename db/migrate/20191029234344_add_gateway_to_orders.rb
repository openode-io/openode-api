class AddGatewayToOrders < ActiveRecord::Migration[6.0]
  def change
    add_column :orders, :gateway, :string, default: 'paypal'
  end
end
