
require 'test_helper'

class SubscriptionControllerTest < ActionDispatch::IntegrationTest
  test '/account/subscriptions/:id/cancel - happy path' do
    user = default_user

    subscription = Subscription.create!(
      subscription_id: "I-CCCANCELGLHXGP65Y",
      user_id: user.id,
      quantity: 1,
      active: true
    )

    post "/account/subscriptions/#{subscription.id}/cancel",
         params: {},
         headers: default_headers_auth,
         as: :json

    assert_response :success
    assert_equal response.parsed_body, {}
  end

  test '/account/subscriptions/:id/cancel - not subscription of user' do
    user = default_user

    subscription = Subscription.where.not(user_id: user.id).first

    post "/account/subscriptions/#{subscription.id}/cancel",
         params: {},
         headers: default_headers_auth,
         as: :json

    assert_response :not_found
  end

  test '/account/subscriptions/ - list subscriptions' do
    user = default_user

    subscription1 = Subscription.create!(
      subscription_id: "I-CCCANCELGLHXGP65Y",
      user_id: user.id,
      quantity: 1,
      active: true
    )

    subscription2 = Subscription.create!(
      subscription_id: "I-CCCANCELGLHXGP65Y2",
      user_id: user.id,
      quantity: 1,
      active: true
    )

    get "/account/subscriptions/",
        headers: default_headers_auth,
        as: :json

    assert_response :success

    assert_equal response.parsed_body.count, 2
    assert_equal response.parsed_body[0]['id'], subscription2.id
    assert_equal response.parsed_body[1]['id'], subscription1.id
  end
end
