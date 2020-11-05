require 'test_helper'

class FriendInviteTest < ActiveSupport::TestCase
  test "happy path create" do
    user = User.last

    invite = FriendInvite.create!(user: user, status: FriendInvite::STATUS_PENDING,
                                  email: "My@email.com")

    assert_equal invite.status, FriendInvite::STATUS_PENDING
    assert_equal invite.user, user
    assert_equal invite.email, "my@email.com"
  end

  test "happy path create with order" do
    user = User.last
    order = Order.last

    invite = FriendInvite.create!(user: user, status: FriendInvite::STATUS_PENDING,
                                  order: order, email: "myemail@gmail.com")

    assert_equal invite.status, FriendInvite::STATUS_PENDING
    assert_equal invite.user, user
    assert_equal invite.order, order
  end

  test "fail if email invalid" do
    user = User.last
    order = Order.last

    invite = FriendInvite.create(user: user, status: FriendInvite::STATUS_PENDING,
                                 order: order, email: "myemailgmail.com")

    assert_equal invite.valid?, false
  end

  test "fail if itself" do
    user = User.last
    order = Order.last

    invite = FriendInvite.create(user: user, status: FriendInvite::STATUS_PENDING,
                                 order: order, email: user.email)

    assert_equal invite.valid?, false
  end

  test "fail if existing user" do
    user = User.last
    other_user = User.where.not(id: user.id).first
    order = Order.last

    invite = FriendInvite.create(user: user, status: FriendInvite::STATUS_PENDING,
                                 order: order, email: other_user.email)

    assert_equal invite.valid?, false
  end

  test "fail if creating too many invites" do
    user = User.last
    order = Order.last
    user.friend_invites.destroy_all

    (1..100).each do |i|
      FriendInvite.create!(user: user, status: FriendInvite::STATUS_PENDING,
                           order: order, email: "myemail#{i}@gmail.com")
    end
    invite = FriendInvite.create(user: user, status: FriendInvite::STATUS_PENDING,
                                 order: order, email: "myemail150@gmail.com")

    assert_equal invite.valid?, false
  end
end
