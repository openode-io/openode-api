# frozen_string_literal: true

class RemoveLocationServerUser < ActiveRecord::Migration[6.0]
  def change
    remove_column :location_servers, :user
  end
end
