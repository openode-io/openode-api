class AddIndexEmailToUsers < ActiveRecord::Migration[5.2]
  def change
    add_index(:users, :email, unique: true) if ENV["DO_MIGRATIONS"]
  end
end
