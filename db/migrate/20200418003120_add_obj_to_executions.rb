class AddObjToExecutions < ActiveRecord::Migration[6.0]
  def change
    add_column :executions, :obj, :text, size: :medium
  end
end
