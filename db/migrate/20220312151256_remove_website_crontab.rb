class RemoveWebsiteCrontab < ActiveRecord::Migration[6.1]
  def change
    remove_column :websites, :crontab
  end
end
