class CreateVaults < ActiveRecord::Migration[6.0]
  def change
    begin
      drop_table :vaults
    rescue => ex
      puts "Error dropping table #{ex}"
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
