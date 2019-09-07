class AddCloudProviderToLocations < ActiveRecord::Migration[6.0]
  def change
    add_column :locations, :cloud_provider, :string, default: "internal"
  end
end
