# frozen_string_literal: true

class CreateHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :histories do |t|
      t.integer :ref_id
      t.string :type
      t.text :obj

      t.timestamps
    end
  end
end
