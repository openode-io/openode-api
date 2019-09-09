class CreateSnapshots < ActiveRecord::Migration[6.0]
  def change
    create_table :snapshots do |t|
      t.references :user, null: false, foreign_key: true
      t.references :website, null: false, foreign_key: true
      t.string :name
      t.string :status, default: "pending"
      t.float :tx_time_in_sec
      t.float :size_in_mb
      t.text :details

      t.timestamps
    end
  end
end
