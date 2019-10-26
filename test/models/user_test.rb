# frozen_string_literal: true

require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'encrypt_passwd correctly' do
    salt = '$2a$10$ThisIsTheSalt22CharsX.'
    expected_encryption = '$2a$10$ThisIsTheSalt22CharsX.ZJyiIxDe4rFcyc7N/fw8gkI4Dvu0gKi'
    assert User.encrypt_passwd('hello', salt) == expected_encryption
  end

  test 'encrypt_passwd passwd_valid?' do
    expected_encryption = '$2a$10$ThisIsTheSalt22CharsX.ZJyiIxDe4rFcyc7N/fw8gkI4Dvu0gKi'
    assert User.passwd_valid?(expected_encryption, 'hello')
  end

  test 'saving and reading user password' do
    attribs = {
      email: 'user1@site.com',
      password_hash: 'Hello123',
      is_admin: false,
      token: '1234s56789101112',
      credits: 80
    }

    user = User.create(attribs)
    assert_equal user.password_hash, User.encrypt_passwd('Hello123')

    user = User.find(user.id)
    assert_equal user.password_hash, User.encrypt_passwd('Hello123')

    user.token = 'whatisthatlongtoken'
    user.password_hash = 'Hello2123!'
    user.save

    user = User.find(user.id)
    assert_equal user.password_hash, User.encrypt_passwd('Hello2123!')
    assert_equal user.token, 'whatisthatlongtoken'
  end

  test 'should fail with weak password' do
    attribs = {
      email: 'user1@site.com',
      password_hash: 'weak',
      is_admin: false,
      token: '1234s56789101112',
      credits: 80
    }

    user = User.create(attribs)
    assert_nil user.id
  end

  test 'should downcase user emails' do
    attribs = {
      email: 'USER10@site.com',
      password_hash: 'NotW3akpasswd!',
      is_admin: false,
      token: '1234s56789101112',
      credits: 80
    }

    user = User.create(attribs)
    assert_equal user.email, 'user10@site.com'
  end

  test 'should create proper default values' do
    attribs = {
      email: 'USER11@site.com',
      password_hash: 'NotW3akpasswd!',
      is_admin: false,
      token: '1234s56789101112',
      credits: 80
    }

    user = User.create(attribs)
    assert_equal [false, 0].include?(user.activated), true
    assert_equal user.activation_hash.length, 32
  end

  test 'should fail to create with an invalid email' do
    attribs = {
      email: 'USER10sitecom',
      password_hash: 'NotW3akpasswd!',
      is_admin: false,
      token: '1234s56789101112',
      credits: 80
    }

    user = User.create(attribs)
    assert_equal user.valid?, false
  end

  test 'should fail to create with a blacklisted email domain' do
    attribs = {
      email: 'asdf@supeRRito.com',
      password_hash: 'NotW3akpasswd!',
      is_admin: false,
      token: '1234s56789101112',
      credits: 80
    }

    assert_equal User.create(attribs).valid?, false
  end

  test 'regen api token' do
    attribs = {
      email: 'USER13@site.com',
      password: 'NotW3akpasswd!',
      is_admin: false,
      token: '1234s567891011123',
      credits: 80
    }

    user = User.create(attribs)
    token = user.token

    user.regen_api_token!
    user_changed = User.find(user.id)

    assert_not_equal token, user_changed.token
  end

  test 'credits? when having credits' do
    user = User.find_by email: 'myadmin@thisisit.com'
    assert_equal user.credits?, true
  end

  test 'has_credits? when no credit' do
    user = User.find_by email: 'myadmin2@thisisit.com'
    assert_equal user.credits?, false
  end

  # can create new website
  test 'can create new website ' do
    user = User.find_by email: 'myadmin@thisisit.com'
    assert_equal user.can_create_new_website, true
  end

  test 'can create new website - cant if has website and no order' do
    user = User.find_by email: 'myadmin2@thisisit.com'

    assert_equal user.can_create_new_website, false
  end
end
