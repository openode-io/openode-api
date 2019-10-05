class CreateDeployments < ActiveRecord::Migration[6.0]
  def change
    create_table :deployments do |t|
      t.references :website, null: false
      t.references :website_location, null: false
      t.string :status
      t.text :result, size: :medium

      t.timestamps
    end
  end
end
