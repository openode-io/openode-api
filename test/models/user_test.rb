require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test "encrypt_passwd correctly" do
    salt = "$2a$10$ThisIsTheSalt22CharsX."
    expected_encryption = "$2a$10$ThisIsTheSalt22CharsX.ZJyiIxDe4rFcyc7N/fw8gkI4Dvu0gKi"
    assert User.encrypt_passwd("hello", salt) == expected_encryption
  end

  test "encrypt_passwd passwd_valid?" do
    expected_encryption = "$2a$10$ThisIsTheSalt22CharsX.ZJyiIxDe4rFcyc7N/fw8gkI4Dvu0gKi"
    assert User.passwd_valid?(expected_encryption, "hello")
  end

  test "saving and reading user password" do
    attribs = {
      email: "user1@site.com" ,
      password_hash: "Hello123",
      is_admin: false,
      token: "1234s56789101112",
      credits: 80
    }

    user = User.create(attribs)
    assert_equal user.password_hash, User.encrypt_passwd("Hello123")

    user = User.find(user.id)
    assert_equal user.password_hash, User.encrypt_passwd("Hello123")

    user.token = "whatisthatlongtoken"
    user.password_hash = "Hello2123!"
    user.save

    user = User.find(user.id)
    assert_equal user.password_hash, User.encrypt_passwd("Hello2123!")
    assert_equal user.token, "whatisthatlongtoken"
  end

  test "should fail with weak password" do
    attribs = {
      email: "user1@site.com" ,
      password_hash: "weak",
      is_admin: false,
      token: "1234s56789101112",
      credits: 80
    }

    user = User.create(attribs)
    assert_nil user.id
  end

  test "should downcase user emails" do
    attribs = {
      email: "USER10@site.com" ,
      password_hash: "NotW3akpasswd!",
      is_admin: false,
      token: "1234s56789101112",
      credits: 80
    }

    user = User.create(attribs)
    assert_equal user.email, "user10@site.com"
  end

  test "should create proper default values" do
    attribs = {
      email: "USER11@site.com" ,
      password_hash: "NotW3akpasswd!",
      is_admin: false,
      token: "1234s56789101112",
      credits: 80
    }

    user = User.create(attribs)
    assert_equal user.activated, false
    assert_equal user.activation_hash.length, 32
  end

  test "regen api token" do
    attribs = {
      email: "USER13@site.com" ,
      password_hash: "NotW3akpasswd!",
      is_admin: false,
      token: "1234s567891011123",
      credits: 80
    }

    user = User.create(attribs)
    token = user.token

    user.regen_api_token!
    user_changed = User.find(user.id)

    assert_not_equal token, user_changed.token
  end

end
