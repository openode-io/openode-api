class AddDomainsIndexToWebsites < ActiveRecord::Migration[5.2]
  def change
    add_index :websites, :domains if ENV["DO_MIGRATIONS"] == "true"
  end
end
