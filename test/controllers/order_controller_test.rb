require 'test_helper'

class OrderControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test '/order/paypal not completed' do
    content = JSON.parse(File.read(Rails.root.join('test', 'fixtures',
                                                   'http', 'payment', 'paypal',
                                                   'paypal.json')))

    content['payment_status'] = 'not completed'

    post '/order/paypal', params: content, as: :json

    assert_response :success
    assert_includes response.parsed_body.to_s, 'not completed'
  end

  test '/order/paypal with invalid body' do
    post '/order/paypal', params: '', as: :json

    assert_response :success
    assert_includes response.parsed_body.to_s, 'not completed'
  end
end
