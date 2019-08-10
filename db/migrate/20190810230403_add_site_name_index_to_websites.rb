class AddSiteNameIndexToWebsites < ActiveRecord::Migration[5.2]
  def change
    add_index :websites, :site_name, unique: true
  end
end
