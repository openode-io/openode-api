class RemoveIsEducationalWebsite < ActiveRecord::Migration[6.0]
  def change
    remove_column :websites, :is_educational
  end
end
