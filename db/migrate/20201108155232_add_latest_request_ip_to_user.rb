class AddLatestRequestIpToUser < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :latest_request_ip, :string, default: ""
  end
end
