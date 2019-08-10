class AddIndexToUsersIsAdmin < ActiveRecord::Migration[5.2]
  def change
    add_index :users, :is_admin
  end
end
