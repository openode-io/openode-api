require 'test_helper'

class OrderControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test '/order/paypal completed' do
    user = User.first
    paypal_fixture_test_path = 'test/fixtures/http/payment/paypal/paypal.json'
    content = JSON.parse(File.read(Rails.root.join(paypal_fixture_test_path)))

    content['custom'] = user.id

    post '/order/paypal', params: content, as: :json

    order_id = response.parsed_body['order_id']
    order = Order.find_by! id: order_id

    assert_response :success
    assert_equal order.amount, 2.0
    assert_equal order.gateway, 'paypal'
    assert_equal order.payment_status, 'Completed'
    assert_equal order.user_id.to_s, user.id.to_s
  end

  test '/order/paypal not completed' do
    paypal_fixture_test_path = 'test/fixtures/http/payment/paypal/paypal.json'
    content = JSON.parse(File.read(Rails.root.join(paypal_fixture_test_path)))

    content['payment_status'] = 'not completed'

    post '/order/paypal', params: content, as: :json

    assert_response :success
    assert_includes response.parsed_body.to_s, 'not completed'
  end

  test '/order/paypal with invalid body' do
    post '/order/paypal', params: '', as: :json

    assert_response :success
    assert_includes response.parsed_body.to_s, 'Order invalid'
  end

  ### Subscriptions
  test 'paypal_subscription_json? - is json' do
    assert OrderController.paypal_subscription_json?('{"hello":"world"}')
  end

  test 'paypal_subscription_json? - not json' do
    assert_not OrderController.paypal_subscription_json?('hello=world&whatis=this')
  end

  test '/order/paypal_subscription - ipn active' do
    user = User.first
    user.subscriptions.destroy_all

    subscription = Subscription.create!(
      subscription_id: "I-C07GLHXGP65Y",
      user_id: user.id,
      quantity: 0
    )

    payload_path = 'test/fixtures/http/paypal/ipn-cancel.txt'
    content = File.read(Rails.root.join(payload_path))

    post '/order/paypal_subscription', params: content

    assert_response :success

    subscription.reload

    assert_equal subscription.quantity, 1
    assert_equal subscription.active, true
  end

  test '/order/paypal_subscription - ipn recurring payment' do
    user = User.first
    user.subscriptions.destroy_all
    user.orders.destroy_all

    payload_path = 'test/fixtures/http/paypal/ipn-recurring-payment.txt'
    content = File.read(Rails.root.join(payload_path))

    post '/order/paypal_subscription', params: content

    assert_response :success
  end

  test '/order/paypal_subscription - ipn inactive' do
    user = User.first
    user.subscriptions.destroy_all

    subscription = Subscription.create!(
      subscription_id: "I-C07GLHXGP65INACTIVE",
      user_id: user.id,
      quantity: 0
    )

    payload_path = 'test/fixtures/http/paypal/ipn-inactive.txt'
    content = File.read(Rails.root.join(payload_path))

    post '/order/paypal_subscription', params: content

    assert_response :success

    subscription.reload

    assert_equal subscription.quantity, 0
    assert_equal subscription.active, false
  end

  test '/order/paypal_subscription - webhook activation' do
    user = User.first
    user.subscriptions.destroy_all

    payload_path = 'test/fixtures/http/paypal/subscription_activated.json'
    content = JSON.parse(File.read(Rails.root.join(payload_path)))

    content['resource']['custom_id'] = user.id

    post '/order/paypal_subscription', params: content, as: :json

    assert_response :success
    assert_includes response.parsed_body['result'], 'ok'

    subscription = user.subscriptions.reload.last

    assert_equal subscription.quantity, 1
    assert_equal subscription.user, user
    assert_equal subscription.subscription_id, "I-19RUCRSR776E"
    assert subscription.active
  end

  test '/order/paypal_subscription - multiple activation of the same subscription id' do
    user = User.first
    user.subscriptions.destroy_all

    payload_path = 'test/fixtures/http/paypal/subscription_activated.json'
    content = JSON.parse(File.read(Rails.root.join(payload_path)))

    content['resource']['custom_id'] = user.id

    post '/order/paypal_subscription', params: content, as: :json

    post '/order/paypal_subscription', params: content, as: :json

    assert_response :success
    assert_includes response.parsed_body['result'], 'error'

    assert_equal user.subscriptions.reload.count, 1
  end
end
