# frozen_string_literal: true

class AddIndexesToVaults < ActiveRecord::Migration[6.0]
  def change
    add_index :vaults, :ref_id
    add_index :vaults, %i[entity_type ref_id]
  end
end
