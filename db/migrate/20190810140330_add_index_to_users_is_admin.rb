class AddIndexToUsersIsAdmin < ActiveRecord::Migration[5.2]
  def change
    add_index :users, :is_admin if ENV["DO_MIGRATIONS"] == "true"
  end
end
