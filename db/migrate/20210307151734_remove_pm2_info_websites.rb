class RemovePm2InfoWebsites < ActiveRecord::Migration[6.1]
  def change
    remove_column :websites, :pm2_info
  end
end
