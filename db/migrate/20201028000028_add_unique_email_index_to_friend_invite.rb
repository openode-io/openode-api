class AddUniqueEmailIndexToFriendInvite < ActiveRecord::Migration[6.0]
  def change
    add_index :friend_invites, :email, unique: true
  end
end
