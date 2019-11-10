class AddEventsToExecutions < ActiveRecord::Migration[6.0]
  def change
    add_column :executions, :events, :text, size: :medium
  end
end
