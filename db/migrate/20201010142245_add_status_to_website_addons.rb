class AddStatusToWebsiteAddons < ActiveRecord::Migration[6.0]
  def change
    add_column :website_addons, :status, :string, default: ""
  end
end
