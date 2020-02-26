# frozen_string_literal: true

require 'test_helper'

class AccountControllerTest < ActionDispatch::IntegrationTest
  test '/account/getToken with valid creds' do
    account = { email: 'myadmin@thisisit.com', password: 'testpw' }
    post '/account/getToken', params: account, as: :json

    assert_response :success
    assert_equal response.parsed_body, '1234s56789'
  end

  test '/account/getToken with not found email' do
    account = { email: 'invalid@thisisit.com', password: 'testpw' }
    post '/account/getToken', params: account, as: :json

    assert_response :not_found
  end

  test '/account/getToken with invalid password' do
    account = { email: 'myadmin@thisisit.com', password: 'invalid' }
    post '/account/getToken', params: account, as: :json

    assert_response :unauthorized
  end

  test '/account/me with valid' do
    u = User.find_by! token: '1234s56789'
    get '/account/me', headers: default_headers_auth, as: :json

    assert_response :success

    assert_equal response.parsed_body['type'], u.type
    assert_equal response.parsed_body['email'], u.email
  end

  test 'PATCH /account/me with valid' do
    u = User.find_by! token: '1234s56789'
    u.newsletter = 0
    u.nb_credits_threshold_notification = 50
    u.save!
    u.reload

    assert_equal u.newsletter, 0

    patch '/account/me',
          headers: default_headers_auth,
          params: {
            account: {
              newsletter: 1,
              nb_credits_threshold_notification: 100
            }
          },
          as: :json

    u.reload

    assert_response :success
    assert_equal u.newsletter, 1
    assert_equal u.nb_credits_threshold_notification, 100
  end

  test 'PATCH /account/me not allowed to change other fields' do
    u = User.find_by! token: '1234s56789'
    credits = u.credits

    patch '/account/me',
          headers: default_headers_auth,
          params: {
            account: {
              credits: 10_000
            }
          },
          as: :json

    u.reload

    assert_response :success
    assert_equal u.credits, credits
  end

  test '/account/me with not logged in' do
    get '/account/me', headers: {}, as: :json

    assert_response :unauthorized
  end

  test '/account/register valid' do
    account = {
      email: 'myadminvalidregister@thisisit.com',
      password: 'Helloworld234',
      password_confirmation: 'Helloworld234'
    }

    post '/account/register', params: account, as: :json

    assert_response :success

    user = User.find(response.parsed_body['id'])

    assert_equal user.email, account[:email]
    assert_equal user.token, response.parsed_body['token']
    assert_equal user.newsletter, 1
    assert_equal user.credits.positive?, true

    mail_sent = ActionMailer::Base.deliveries.first
    assert_equal mail_sent.subject, 'Welcome to opeNode!'
    assert_includes mail_sent.body.raw_source, 'Activate your account'
    assert_includes mail_sent.body.raw_source, 'openode.io'
  end

  test '/account/register valid without newsletter' do
    account = {
      email: 'myadminvalidregister@thisisit.com',
      password: 'Helloworld234',
      password_confirmation: 'Helloworld234',
      newsletter: 0
    }

    post '/account/register', params: account, as: :json

    assert_response :success

    user = User.find(response.parsed_body['id'])

    assert_equal user.email, account[:email]
    assert_equal user.token, response.parsed_body['token']
    assert_equal user.newsletter, 0

    mail_sent = ActionMailer::Base.deliveries.first
    assert_equal mail_sent.subject, 'Welcome to opeNode!'
  end

  test '/account/register password does not match' do
    account = {
      email: 'myadminvalidregister@thisisit.com',
      password: 'Helloworld234',
      password_confirmation: 'Helloworld234567'
    }

    post '/account/register', params: account, as: :json

    assert response.status >= 400
  end

  test '/account/forgot-password with valid email' do
    user = default_user

    post '/account/forgot-password',
         as: :json,
         params: { email: user.email }

    user.reload

    mail_sent = ActionMailer::Base.deliveries.first

    assert_equal mail_sent.subject, 'opeNode Password Reset'
    assert_includes mail_sent.body.raw_source, "/reset/#{user.reset_token}"
  end

  test '/account/forgot-password with invalid email' do
    user = default_user
    user.reset_token = nil
    user.save!

    post '/account/forgot-password',
         as: :json,
         params: { email: "hiworld@gmaill.com" }

    user.reload

    assert_equal user.reset_token, nil
  end

  test '/account/verify-reset-token with invalid reset token' do
    user = default_user
    user.regen_reset_token!

    post '/account/verify-reset-token',
         as: :json,
         params: { reset_token: "invalid" }

    assert_response :not_found
  end

  test '/account/verify-reset-token with valid reset token' do
    user = default_user
    user.regen_reset_token!
    original_reset_token = user.reset_token

    post '/account/verify-reset-token',
         as: :json,
         params: { reset_token: user.reset_token }

    assert_response :success

    assert response.parsed_body['token'], user.token

    # once used, it should change
    user.reload
    assert_equal user.reset_token != original_reset_token, true
  end
end
