class AddIndexToWebsiteAddonsWebsiteId < ActiveRecord::Migration[6.0]
  def change
    add_index(:website_addons, [:website_id])
  end
end
