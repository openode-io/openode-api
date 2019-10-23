# frozen_string_literal: true

class AddDayOneMailAtIndexToUsers < ActiveRecord::Migration[5.2]
  def change
    add_index :users, :day_one_mail_at if ENV['DO_MIGRATIONS'] == 'true'
  end
end
