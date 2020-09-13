class CreateWebsiteAddons < ActiveRecord::Migration[6.0]
  def change
    create_table :website_addons do |t|
      t.bigint :website_id
      t.bigint :addon_id
      t.string :name
      t.text :obj, size: :medium

      t.timestamps
    end
  end
end
