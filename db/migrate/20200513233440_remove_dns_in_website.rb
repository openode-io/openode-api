class RemoveDnsInWebsite < ActiveRecord::Migration[6.0]
  def change
    remove_column :websites, :dns
  end
end
