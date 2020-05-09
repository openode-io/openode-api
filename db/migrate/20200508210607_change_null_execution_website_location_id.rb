class ChangeNullExecutionWebsiteLocationId < ActiveRecord::Migration[6.0]
  def change
    change_column :executions, :website_location_id, :bigint, null: true
  end
end
