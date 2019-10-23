# frozen_string_literal: true

class CreateLocationServers < ActiveRecord::Migration[5.2]
  def change
    if ENV['DO_MIGRATIONS'] == 'true'
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
      end
    end

    add_index :location_servers, :cloud_type if ENV['DO_MIGRATIONS'] == 'true'
  end
end
