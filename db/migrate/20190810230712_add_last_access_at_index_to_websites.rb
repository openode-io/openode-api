class AddLastAccessAtIndexToWebsites < ActiveRecord::Migration[5.2]
  def change
    add_index :websites, :last_access_at
  end
end
