# frozen_string_literal: true

class AddNotifiedLowCreditIndexToUsers < ActiveRecord::Migration[5.2]
  def change
    add_index :users, :notified_low_credit if ENV['DO_MIGRATIONS'] == 'true'
  end
end
