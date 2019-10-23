# frozen_string_literal: true

class CreateWebsiteLocations < ActiveRecord::Migration[5.2]
  def change
    if ENV['DO_MIGRATIONS'] == 'true'
      create_table :website_locations do |t|
        t.references :website, foreign_key: true
        t.references :location, foreign_key: true
        t.references :location_server, foreign_key: true
        t.integer :extra_storage
        t.integer :nb_cpus
        t.integer :port
        t.integer :second_port
        t.integer :running_port

        t.timestamps
      end
    end
  end
end
