class CreateLocationServers < ActiveRecord::Migration[5.2]
  def change
    create_table :location_servers do |t|
      t.references :location, foreign_key: true
      t.string :ip
      t.string :user
      t.string :password
      t.integer :ram_mb
      t.integer :cpus
      t.integer :disk_gb
      t.text :docker_snapshot
      t.string :cloud_type

      t.timestamps
    end if ENV["DO_MIGRATIONS"]

    add_index :location_servers, :cloud_type if ENV["DO_MIGRATIONS"]
  end


end
