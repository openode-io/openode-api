class CreateFriendInvites < ActiveRecord::Migration[6.0]
  def change
    create_table :friend_invites do |t|
      t.references :user, null: false
      t.bigint :order_id
      t.string :status
      t.string :email

      t.timestamps
    end
  end
end
