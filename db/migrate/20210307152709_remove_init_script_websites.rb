class RemoveInitScriptWebsites < ActiveRecord::Migration[6.1]
  def change
    remove_column :websites, :init_script
  end
end
