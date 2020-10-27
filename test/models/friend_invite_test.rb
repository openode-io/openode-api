require 'test_helper'

class FriendInviteTest < ActiveSupport::TestCase
  test "happy path create" do
    user = User.last

    invite = FriendInvite.create!(user: user, status: FriendInvite::STATUS_PENDING)

    assert_equal invite.status, FriendInvite::STATUS_PENDING
    assert_equal invite.user, user
  end

  test "happy path create with order" do
    user = User.last
    order = Order.last

    invite = FriendInvite.create!(user: user, status: FriendInvite::STATUS_PENDING, order: order)

    assert_equal invite.status, FriendInvite::STATUS_PENDING
    assert_equal invite.user, user
    assert_equal invite.order, order
  end
end
