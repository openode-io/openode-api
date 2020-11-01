
require 'test_helper'

class LibTasksUpdateFriendInviteTest < ActiveSupport::TestCase
  test "happy path" do
    FriendInvite.destroy_all

    user = User.last
    user_invited = User.where.not(id: user.id).first

    invite = FriendInvite.create!(user: user, status: FriendInvite::STATUS_PENDING, email: user_invited.email)

    invoke_task "update:friend_invites"

    invite.reload

    assert_equal invite.status, FriendInvite::STATUS_APPROVED
    assert invite.order
    assert_equal invite.order.amount, 1
    assert_equal invite.order.user, user
  end

  test "too old invite" do
    FriendInvite.destroy_all

    user = User.last

    invite = FriendInvite.create!(user: user, status: FriendInvite::STATUS_PENDING, email: "invalid@email.com")
    invite.created_at = 10.days.ago
    invite.save

    invoke_task "update:friend_invites"

    assert_not FriendInvite.find_by(id: invite.id)
  end
end
