class AddOpenSourceActivatedIndexToWebsites < ActiveRecord::Migration[6.0]
  def change
    add_index(:websites, [:open_source_activated])
  end
end
