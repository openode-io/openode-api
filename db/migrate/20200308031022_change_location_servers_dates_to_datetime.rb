class ChangeLocationServersDatesToDatetime < ActiveRecord::Migration[6.0]
  def change
    change_column :location_servers, :created_at, :datetime, precision: 6
    change_column :location_servers, :updated_at, :datetime, precision: 6
  end
end
