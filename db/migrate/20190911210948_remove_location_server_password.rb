# frozen_string_literal: true

class RemoveLocationServerPassword < ActiveRecord::Migration[6.0]
  def change
    remove_column :location_servers, :password
  end
end
