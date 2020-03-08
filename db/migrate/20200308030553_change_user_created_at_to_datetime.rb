class ChangeUserCreatedAtToDatetime < ActiveRecord::Migration[6.0]
  def change
    change_column :users, :created_at, :datetime, precision: 6
  end
end
