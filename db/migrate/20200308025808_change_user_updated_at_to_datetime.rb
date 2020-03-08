class ChangeUserUpdatedAtToDatetime < ActiveRecord::Migration[6.0]
  def change
    change_column :users, :updated_at, :datetime, precision: 6
  end
end
