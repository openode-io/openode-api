# frozen_string_literal: true

class CreateVaults < ActiveRecord::Migration[6.0]
  def change
    begin
      drop_table :vaults
    rescue StandardError => e
      puts "Error dropping table #{e}"
    end

    create_table :vaults do |t|
      t.integer :ref_id
      t.string :entity_type
      t.text :encrypted_data
      t.text :encrypted_data_iv

      t.timestamps
    end
  end
end
