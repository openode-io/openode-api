class AddReplicasToWebsiteLocations < ActiveRecord::Migration[6.0]
  def change
    add_column :website_locations, :replicas, :int, default: 1
  end
end
