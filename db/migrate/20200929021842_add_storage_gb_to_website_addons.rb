class AddStorageGbToWebsiteAddons < ActiveRecord::Migration[6.0]
  def change
    add_column :website_addons, :storage_gb, :integer, default: 0
  end
end
