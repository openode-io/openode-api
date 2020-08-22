class AddUniqIndexWebsiteAddonName < ActiveRecord::Migration[6.0]
  def change
    add_index(:website_addons, [:website_id, :name], unique: true)
  end
end
