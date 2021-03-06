# frozen_string_literal: true

class AddCreditsCheckAtIndexToWebsites < ActiveRecord::Migration[5.2]
  def change
    add_index :websites, :credits_check_at if ENV['DO_MIGRATIONS'] == 'true'
  end
end
