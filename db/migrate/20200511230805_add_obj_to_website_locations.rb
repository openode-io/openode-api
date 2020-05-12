class AddObjToWebsiteLocations < ActiveRecord::Migration[6.0]
  def change
    add_column :website_locations, :obj, :text
  end
end
