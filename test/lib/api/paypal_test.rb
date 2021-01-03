
require 'test_helper'

class ApiPaypalTest < ActiveSupport::TestCase
  test 'refresh_access_token - happy path' do
    paypal_api = Api::Paypal.new

    access_token = paypal_api.refresh_access_token

    assert_equal access_token, "myaccesstoken"
  end

  test 'get subscription - happy path' do
    paypal_api = Api::Paypal.new

    paypal_api.refresh_access_token

    result = paypal_api.execute(:get, "/v1/billing/subscriptions/MY_SUB")

    assert_equal result, { "attri" => "bute" }
  end
end
