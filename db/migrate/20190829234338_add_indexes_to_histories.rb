# frozen_string_literal: true

class AddIndexesToHistories < ActiveRecord::Migration[6.0]
  def change
    add_index :histories, :type
    add_index :histories, %i[type ref_id]
  end
end
