class AddAccountTypeToWebsiteAddons < ActiveRecord::Migration[6.0]
  def change
    add_column :website_addons, :account_type, :string
  end
end
