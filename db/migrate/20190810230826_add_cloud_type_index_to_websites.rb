# frozen_string_literal: true

class AddCloudTypeIndexToWebsites < ActiveRecord::Migration[5.2]
  def change
    add_index :websites, :cloud_type if ENV['DO_MIGRATIONS'] == 'true'
  end
end
