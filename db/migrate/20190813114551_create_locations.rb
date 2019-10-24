# frozen_string_literal: true

class CreateLocations < ActiveRecord::Migration[5.2]
  def change
    return unless ENV['DO_MIGRATIONS'] == 'true'

    create_table :locations do |t|
      t.string :str_id
      t.string :full_name
      t.string :country_fullname

      t.timestamps
    end
  end
end
