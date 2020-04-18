class AddParentExecutionIdToExecutions < ActiveRecord::Migration[6.0]
  def change
    add_column :executions, :parent_execution_id, :bigint
    add_index :executions, :parent_execution_id
  end
end
