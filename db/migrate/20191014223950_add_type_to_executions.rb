
class AddTypeToExecutions < ActiveRecord::Migration[6.0]
  def change
    add_column :executions, :type, :string, default: 'Deployment'
  end
end
