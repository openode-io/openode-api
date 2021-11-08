class RemoveWebsiteInstanceType < ActiveRecord::Migration[6.1]
  def change
    remove_column :websites, :instance_type
  end
end
