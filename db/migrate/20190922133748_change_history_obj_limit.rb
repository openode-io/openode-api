class ChangeHistoryObjLimit < ActiveRecord::Migration[6.0]
  def change
  	change_column :histories, :obj, :text, limit: 16.megabytes - 1
  end
end
