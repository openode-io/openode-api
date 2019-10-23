# frozen_string_literal: true

class ChangeWebsitesValidToBoolean < ActiveRecord::Migration[6.0]
  def change
    change_column :websites, :valid, :boolean
  end
end
