class AddValidIndexToWebsites < ActiveRecord::Migration[5.2]
  def change
    add_index :websites, :valid
  end
end
