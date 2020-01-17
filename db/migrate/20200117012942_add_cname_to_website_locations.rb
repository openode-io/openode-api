class AddCnameToWebsiteLocations < ActiveRecord::Migration[6.0]
  def change
    add_column :website_locations, :cname, :string
  end
end
