class AddCreatedByIpToFriendInvites < ActiveRecord::Migration[6.0]
  def change
    add_column :friend_invites, :created_by_ip, :string, default: ""
  end
end
