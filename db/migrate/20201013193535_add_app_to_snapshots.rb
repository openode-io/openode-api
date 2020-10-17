class AddAppToSnapshots < ActiveRecord::Migration[6.0]
  def change
    add_column :snapshots, :app, :string, default: "www"
  end
end
