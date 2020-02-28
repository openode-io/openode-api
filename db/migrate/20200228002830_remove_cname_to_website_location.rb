class RemoveCnameToWebsiteLocation < ActiveRecord::Migration[6.0]
  def change
    remove_column :website_locations, :cname
  end
end
