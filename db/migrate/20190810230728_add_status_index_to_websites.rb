class AddStatusIndexToWebsites < ActiveRecord::Migration[5.2]
  def change
    add_index :websites, :status if ENV["DO_MIGRATIONS"] == "true"
  end
end
