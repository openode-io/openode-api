class ChangeNullExecutionWebsiteId < ActiveRecord::Migration[6.0]
  def change
    change_column :executions, :website_id, :bigint, null: true
  end
end
