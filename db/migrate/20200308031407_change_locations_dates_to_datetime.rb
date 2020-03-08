class ChangeLocationsDatesToDatetime < ActiveRecord::Migration[6.0]
  def change
    change_column :locations, :created_at, :datetime, precision: 6
    change_column :locations, :updated_at, :datetime, precision: 6
  end
end
