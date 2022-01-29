class SetDefaultExtraStorageWebsiteLocations < ActiveRecord::Migration[6.1]
  def change
    change_column_default(:website_locations, :extra_storage, 0)
  end
end
