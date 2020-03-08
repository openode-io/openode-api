class ChangeWebsitesDatesToDatetime < ActiveRecord::Migration[6.0]
  def change
    change_column :websites, :created_at, :datetime, precision: 6
    change_column :websites, :updated_at, :datetime, precision: 6
  end
end
