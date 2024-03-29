# frozen_string_literal: true

require 'test_helper'

class UserTest < ActiveSupport::TestCase
  setup do
    reset_emails
  end

  test 'encrypt_passwd correctly' do
    salt = '$2a$10$ThisIsTheSalt22CharsX.'
    expected_encryption = '$2a$10$ThisIsTheSalt22CharsX.ZJyiIxDe4rFcyc7N/fw8gkI4Dvu0gKi'
    assert User.encrypt_passwd('hello', salt) == expected_encryption
  end

  test 'encrypt_passwd passwd_valid?' do
    expected_encryption = '$2a$10$ThisIsTheSalt22CharsX.ZJyiIxDe4rFcyc7N/fw8gkI4Dvu0gKi'
    assert User.passwd_valid?(expected_encryption, 'hello')
  end

  test 'distribute free credits only once' do
    attribs = {
      email: 'user1@site.com',
      password: 'Hello123',
      is_admin: false,
      token: '1234s56789101112'
    }

    user = User.create!(attribs)

    assert user.credits.positive?
    assert GlobalEmailRegistration.last.key == "user1@site.com"

    user.destroy!

    user = User.create!(attribs)

    assert user.credits.zero?
  end

  test 'saving and reading user password' do
    attribs = {
      email: 'user1@site.com',
      password: 'Hello123',
      is_admin: false,
      token: '1234s56789101112',
      credits: 80
    }

    user = User.create!(attribs)
    assert_equal user.password_hash, User.encrypt_passwd('Hello123')

    user = User.find(user.id)
    assert_equal user.password_hash, User.encrypt_passwd('Hello123')

    user.token = 'whatisthatlongtoken'
    user.password = 'Hello2123!'
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

  test 'user type - regular' do
    u = default_user

    assert [0, false].include?(u.is_admin)
    assert_equal u.type, 'regular'
  end

  test 'user type - admin' do
    u = default_user

    u.is_admin = true
    u.save!

    assert [1, true].include?(u.is_admin)
    assert_equal u.type, 'admin'
  end

  test 'should remove orders on destroy' do
    o = Order.last
    u = o.user

    u.websites.each do |w|
      w.status = "N/A"
      w.save!
      w.website_locations.destroy_all
    end

    u.destroy

    assert_nil Order.find_by id: o.id
  end

  test 'saving account' do
    attribs = {
      email: 'user10@site.com',
      password: 'NotW3akpasswd!',
      is_admin: false,
      token: '1234s56789101112',
      credits: 80
    }

    user = User.create!(attribs)
    user.account = {
      attrib1: 'toto',
      attrib2: 'tata'
    }
    user.save
    user.reload

    assert_equal user.account['attrib1'], 'toto'
    assert_equal user.account['attrib2'], 'tata'
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

  test 'create with randomly generated password' do
    attribs = {
      email: 'USER10@site.com',
      password: Str::Rand.password
    }

    user = User.create(attribs)
    assert_equal user.valid?, true
  end

  test 'should create proper default values' do
    attribs = {
      email: 'USER11@site.com',
      password_hash: 'NotW3akpasswd!',
      is_admin: false,
      token: '1234s56789101112'
    }

    user = User.create(attribs)
    assert_equal [false, 0].include?(user.activated), true
    assert_equal user.activation_hash.length, 32
    assert_equal user.credits.positive?, true
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

  # has active websites?
  test 'active_websites? with no website' do
    u = default_user
    u.websites.each(&:destroy)

    assert u.active_websites?, false
  end

  test 'active_websites? with one inactive website' do
    u = default_user
    w = u.websites.first!
    w.change_status!(Website::STATUS_OFFLINE)
    wl = w.website_locations.first
    wl.extra_storage = 0
    wl.save!

    assert u.active_websites?, false
  end

  test 'active_websites? with one active website' do
    u = default_user
    w = u.websites.first!
    w.change_status!(Website::STATUS_ONLINE)

    assert u.active_websites?, true
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

  test 'fields should not be regen on save' do
    u = default_user

    orig_token = u.token
    orig_pw_hash = u.password_hash
    orig_activation_hash = u.activation_hash

    u.updated_at = Time.current
    u.save

    u.reload

    assert_equal u.activation_hash, orig_activation_hash
    assert_equal u.token, orig_token
    assert_equal u.password_hash, orig_pw_hash
  end

  test 'regen reset token' do
    u = default_user
    u.reset_token = nil
    u.save!
    u.regen_reset_token!

    assert_equal u.reset_token.length, 64
  end

  test 'credits? when having credits' do
    user = User.find_by email: 'myadmin@thisisit.com'
    assert_equal user.credits?, true
  end

  test 'credits? with minimum limit too high' do
    user = User.find_by email: 'myadmin@thisisit.com'
    assert_equal user.credits?(user.credits + 1), false
  end

  test 'credits? with minimum limit lower' do
    user = User.find_by email: 'myadmin@thisisit.com'
    assert_equal user.credits?(user.credits - 1), true
  end

  test 'credits? with minimum limit eq' do
    user = User.find_by email: 'myadmin@thisisit.com'
    assert_equal user.credits?(user.credits), true
  end

  test 'has_credits? when no credit' do
    user = User.find_by email: 'myadmin2@thisisit.com'
    assert_equal user.credits?, false
  end

  test 'orders? when having orders' do
    user = default_user

    assert user.orders.count.positive?
    assert user.orders?
  end

  test 'orders? when no order' do
    user = default_user
    user.orders.each(&:destroy)

    assert user.orders.count.zero?
    assert_equal user.orders?, false
  end

  # can create new website
  test 'can create new website ' do
    user = User.find_by email: 'myadmin@thisisit.com'
    assert_equal user.can_create_new_website?, true
  end

  test 'can create new website - cant if has website and no order' do
    user = User.find_by email: 'myadmin2@thisisit.com'

    assert_equal user.can_create_new_website?, false
  end

  # can?
  test 'can? anything if owner' do
    website = default_website
    user = website.user

    assert_equal user.can?(Website::PERMISSION_PLAN, website), true
  end

  test 'can? anything if super admin' do
    website = default_website
    user = User.where.not(id: website.user.id).first
    user.is_admin = true
    user.save!

    assert_equal user.can?(Website::PERMISSION_PLAN, website), true
  end

  test 'can? throw forbidden if not owner and not collaborator' do
    Collaborator.all.destroy_all
    website = default_website
    user_to_test = User.where('id != ?', website.user_id).first

    assert_raise User::Forbidden do
      user_to_test.can?(Website::PERMISSION_PLAN, website)
    end
  end

  test 'can? throw forbidden if collaborator but not this action' do
    Collaborator.all.destroy_all
    website = default_website
    user_to_test = User.where('id != ?', website.user_id).first

    Collaborator.create!(
      website: website,
      user: user_to_test,
      permissions: [Website::PERMISSION_LOCATION]
    )

    user_to_test.can?(Website::PERMISSION_LOCATION, website)

    assert_raise User::Forbidden do
      user_to_test.can?(Website::PERMISSION_PLAN, website)
    end
  end

  test 'can? if root collaborator' do
    Collaborator.all.destroy_all
    website = default_website
    user_to_test = User.where('id != ?', website.user_id).first

    Collaborator.create!(
      website: website,
      user: user_to_test,
      permissions: [Website::PERMISSION_ROOT]
    )

    Website::PERMISSIONS.each do |perm|
      assert_equal user_to_test.can?(perm, website), true
    end
  end

  # first unused coupon
  test 'first unused coupon with one unused' do
    user = User.first
    coupon = Coupon.first
    user.coupons = [coupon]
    user.save

    first_coupon = user.first_unused_coupon
    assert_not_nil first_coupon
    assert_equal first_coupon['str_id'], coupon.str_id
  end

  test 'first unused coupon with one unused, two in total' do
    user = User.first
    coupon = Coupon.first
    user.coupons = [coupon, Coupon.last]
    user.coupons[0]['used'] = true
    user.save

    first_coupon = user.first_unused_coupon
    assert_not_nil first_coupon
    assert_equal first_coupon['str_id'], Coupon.last.str_id
  end

  test 'first unused coupon with none' do
    user = User.first
    user.coupons = []
    user.save

    first_coupon = user.first_unused_coupon
    assert_nil first_coupon
  end

  # use coupon
  test 'use coupon' do
    user = User.first
    coupon = Coupon.first
    user.use_coupon!(coupon)

    user.reload

    assert_equal user.coupons.length, 1
    assert_equal user.coupons[0]['str_id'], coupon.str_id
    assert_equal user.coupons[0]['used'], true
  end

  test 'use coupon if nil' do
    user = User.first
    user.coupons = []
    user.save
    user.use_coupon!(nil)

    user.reload

    assert_equal user.coupons.length, 0
  end

  # collaborator_websites
  test "collaborator_websites with one" do
    c = Collaborator.first
    user = User.find_by email: 'myadmin2@thisisit.com'

    assert_equal user.collaborator_websites.length, 1
    assert_equal user.collaborator_websites.first.site_name, c.website.site_name
  end

  # websites with access
  test "websites_with_access" do
    user = User.find_by email: 'myadmin2@thisisit.com'

    assert_equal user.websites.map(&:site_name), ["www.what.is", "testsite2", "app.what.is"]

    new_website = Website.find_by site_name: "testsite"

    Collaborator.create!(
      user: user,
      website: new_website,
      permissions: [Website::PERMISSION_ROOT]
    )

    user.reload

    expected_with_access = ["www.what.is", "testsite2", "app.what.is", "testsite"]
    assert_equal user.websites_with_access.map(&:site_name), expected_with_access
  end

  # selecting users which should be notified
  test "users lacking_credits" do
    users_lacking_credits = User.lacking_credits

    users_emails = users_lacking_credits.map(&:email)
    assert_equal users_lacking_credits.count, 2
    assert_includes users_emails, 'myadmin2@thisisit.com'
    assert_includes users_emails, 'myadmin33@thisisit.com'
  end

  test "users not_notified_low_credit" do
    users_lacking_credits = User.not_notified_low_credit

    users_emails = users_lacking_credits.map(&:email)
    assert_equal users_lacking_credits.count, 2
    assert_includes users_emails, 'myadmin@thisisit.com'
    assert_includes users_emails, 'myadmin2@thisisit.com'
  end

  test "users not_notified_low_credit and lacking credits" do
    users = User.lacking_credits.not_notified_low_credit

    users_emails = users.map(&:email)
    assert_equal users.count, 1
    assert_includes users_emails, 'myadmin2@thisisit.com'
  end

  test "users which should be notified" do
    users = User
            .lacking_credits
            .not_notified_low_credit
            .having_websites_in_statuses([Website::STATUS_ONLINE])

    users_emails = users.map(&:email)
    assert_equal users.count, 1
    assert_includes users_emails, 'myadmin2@thisisit.com'
  end

  test "users which should be notified - no one" do
    user = User.find_by! email: 'myadmin2@thisisit.com'

    user.websites.each do |w|
      w.status = Website::STATUS_OFFLINE
      w.save!
    end

    users = User
            .lacking_credits
            .not_notified_low_credit
            .having_websites_in_statuses([Website::STATUS_ONLINE])

    assert_equal users.count, 0
  end

  test "updating user email should redo activation" do
    new_email = 'asdfasdf@gmail.com'

    user = default_user
    original_activation_hash = user.activation_hash
    user.email = new_email
    user.save

    user.reload

    assert_equal user.email, new_email
    assert [0, false].include?(user.activated)
    assert_not_equal user.activation_hash, original_activation_hash

    mail_sent = ActionMailer::Base.deliveries.first
    assert_equal mail_sent.subject, 'Welcome to opeNode!'
    assert_includes mail_sent.body.raw_source, 'Activate your account'
    assert_includes mail_sent.body.raw_source, 'openode.io'
  end

  test "updating user email should not redo activation" do
    user = default_user
    original_activation_hash = user.activation_hash
    user.token = 'toto'
    user.activated = true
    user.save!

    user.reload

    assert_equal user.token, 'toto'
    assert [1, true].include?(user.activated)
    assert_equal user.activation_hash, original_activation_hash

    mail_sent = ActionMailer::Base.deliveries.first
    assert_nil mail_sent
  end

  # destroy

  test "destroy - without website" do
    user = default_user
    user.websites.each(&:destroy)
    user.websites.reload

    uid = user.id
    user.destroy

    assert_nil User.find_by(id: uid)
  end

  test "destroy - with active website should fail" do
    user = default_user
    w = user.websites.first

    w.change_status!(Website::STATUS_ONLINE)

    assert_raise ApplicationRecord::ValidationError do
      user.destroy
    end

    assert user.reload
    assert w.reload
  end

  test "destroy - with inactive websites should work" do
    user = default_user
    first_website = user.websites.first

    user.websites.each do |w|
      w.change_status!(Website::STATUS_OFFLINE)

      w.website_locations.each do |wl|
        wl.extra_storage = 0
        wl.save!
      end
    end

    user.destroy

    assert_nil User.find_by(id: user.id)
    assert_nil Website.find_by(id: first_website.id)
  end

  test "verify_email! - happy path" do
    user = default_user
    user.activated = false
    user.save!

    user.verify_email!

    user.reload

    assert [1, true].include?(user.activated)
    verification = user.user_email_verifications.last

    assert verification
    assert_equal verification.obj['result'], "valid"
  end
end
