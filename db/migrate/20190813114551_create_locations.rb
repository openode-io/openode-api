class CreateLocations < ActiveRecord::Migration[5.2]
  def change
    create_table :locations do |t|
      t.string :str_id
      t.string :full_name
      t.string :country_fullname

      t.timestamps
    end if ENV["DO_MIGRATIONS"] == "true"
  end
end
