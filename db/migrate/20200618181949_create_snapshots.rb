class CreateSnapshots < ActiveRecord::Migration[6.0]
  def change
    create_table :snapshots do |t|
      t.references :website, null: false
      t.string :status, default: 'pending'
      t.datetime :expire_at
      t.float :size_mb
      t.string :uid
      t.string :path
      t.string :destination_path
      t.string :url
      t.text :steps, size: :medium

      t.timestamps
    end
  end
end
