class RemoveWebsiteSubStatus < ActiveRecord::Migration[6.1]
  def change
    remove_column :websites, :sub_status
  end
end
