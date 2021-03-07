class AddOneClickAppWebsites < ActiveRecord::Migration[6.1]
  def change
    add_column :websites, :one_click_app, :text, size: :medium
  end
end
