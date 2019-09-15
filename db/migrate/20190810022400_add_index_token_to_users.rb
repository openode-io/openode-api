class AddIndexTokenToUsers < ActiveRecord::Migration[5.2]
  def change
    add_index :users, :token, unique: true if ENV["DO_MIGRATIONS"] == "true"
  end
end
