
require 'test_helper'

class SuperAdmin::OrdersControllerTest < ActionDispatch::IntegrationTest
  test "with matches" do
    get '/super_admin/orders?search=omplete',
        as: :json,
        headers: super_admin_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 2
    assert_equal response.parsed_body[0]["email"], "myadmin@thisisit.com"
  end

  test "without match" do
    get '/super_admin/orders?search=ompleteasdf',
        as: :json,
        headers: super_admin_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 0
  end

  test "make new valid order" do
    u = default_user
    credits_before = u.credits

    post '/super_admin/orders',
         as: :json,
         params: {
           user_id: u.id,
           amount: 12.0,
           payment_status: 'Completed',
           gateway: 'paypal',
           reason: 'helloworld'
         },
         headers: super_admin_headers_auth

    u.reload
    order = Order.find_by! id: response.parsed_body['id']

    assert_response :success
    assert_equal credits_before + 12 * 100, u.credits
    assert_equal order.amount, 12

    mail_sent = ActionMailer::Base.deliveries.last

    assert_equal mail_sent.subject, "opeNode Order ##{order.id} Confirmation"
  end
end
