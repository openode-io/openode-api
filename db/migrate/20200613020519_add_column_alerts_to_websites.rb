class AddColumnAlertsToWebsites < ActiveRecord::Migration[6.0]
  def change
    add_column :websites, :alerts, :text
  end
end
