class ChangeUsersNotifiedLowCreditToBoolean < ActiveRecord::Migration[6.0]
  def change
    change_column :users, :notified_low_credit, :boolean
  end
end
