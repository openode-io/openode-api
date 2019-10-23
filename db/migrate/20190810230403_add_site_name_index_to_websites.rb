# frozen_string_literal: true

class AddSiteNameIndexToWebsites < ActiveRecord::Migration[5.2]
  def change
    add_index :websites, :site_name, unique: true if ENV['DO_MIGRATIONS'] == 'true'
  end
end
