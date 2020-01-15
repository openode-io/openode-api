class AddOpenSourceActivatedToWebsites < ActiveRecord::Migration[6.0]
  def change
    add_column :websites, :open_source_activated, :boolean, default: false
  end
end
