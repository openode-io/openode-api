
require 'test_helper'

class LibTasksUpdateFriendInviteTest < ActiveSupport::TestCase
  test "happy path" do
    FriendInvite.destroy_all

    user = User.last
    user_invited = User.where.not(id: user.id).first
    user_invited.latest_request_ip = "127.0.0.2"
    user_invited.save!

    invite = FriendInvite.create!(user: user, status: FriendInvite::STATUS_PENDING,
                                  email: "my@invalid.com", created_by_ip: "127.0.0.1")
    invite.email = user_invited.email
    invite.save!

    invoke_task "update:friend_invites"

    invite.reload

    assert_equal invite.status, FriendInvite::STATUS_APPROVED
    assert invite.order
    assert_equal invite.order.amount, 1
    assert_equal invite.order.user, user
  end

  test "same ip are not allowed" do
    FriendInvite.destroy_all

    user = User.last
    user_invited = User.where.not(id: user.id).first
    user_invited.latest_request_ip = "127.0.0.1"
    user_invited.save!

    invite = FriendInvite.create!(user: user, status: FriendInvite::STATUS_PENDING,
                                  email: "my@invalid.com", created_by_ip: "127.0.0.1")
    invite.email = user_invited.email
    invite.save!

    invoke_task "update:friend_invites"

    invite.reload

    assert_equal invite.status, FriendInvite::STATUS_PENDING
    assert_not invite.order
  end

  test "too old invite" do
    FriendInvite.destroy_all

    user = User.last
    user.latest_request_ip = "127.0.0.2"
    user.save!

    invite = FriendInvite.create!(user: user, status: FriendInvite::STATUS_PENDING,
                                  email: "invalid@email.com", created_by_ip: "127.0.0.1")
    invite.created_at = 10.days.ago
    invite.save

    invoke_task "update:friend_invites"

    assert_not FriendInvite.find_by(id: invite.id)
  end
end
