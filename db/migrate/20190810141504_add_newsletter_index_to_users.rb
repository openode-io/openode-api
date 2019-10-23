# frozen_string_literal: true

class AddNewsletterIndexToUsers < ActiveRecord::Migration[5.2]
  def change
    add_index :users, :newsletter if ENV['DO_MIGRATIONS'] == 'true'
  end
end
