class ChangeWebsiteLocationsDatesToDatetime < ActiveRecord::Migration[6.0]
  def change
    change_column :website_locations, :created_at, :datetime, precision: 6
    change_column :website_locations, :updated_at, :datetime, precision: 6
  end
end
