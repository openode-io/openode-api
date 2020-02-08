class RemoveUniquePortIndexWebsiteLocations < ActiveRecord::Migration[6.0]
  def change
    remove_index :website_locations, column: [:location_server_id, :port]
  end
end
