class AddIndexUserLatestRequestIp < ActiveRecord::Migration[6.1]
  def change
    add_index :users, :latest_request_ip
  end
end
