class RemoveContainerIdField < ActiveRecord::Migration[6.1]
  def change
    remove_column :websites, :container_id
  end
end
