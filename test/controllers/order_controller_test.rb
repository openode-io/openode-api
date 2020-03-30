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
end
