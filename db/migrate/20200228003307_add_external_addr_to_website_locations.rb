class AddExternalAddrToWebsiteLocations < ActiveRecord::Migration[6.0]
  def change
    add_column :website_locations, :external_addr, :string
  end
end
