
require 'test_helper'

class AddonsControllerTest < ActionDispatch::IntegrationTest
  test '/global/addons' do
    get '/global/addons', as: :json

    assert_response :success

    assert_equal response.parsed_body.length, 2
    assert_equal response.parsed_body[0]['name'], 'name1'
    assert_equal response.parsed_body[1]['name'], 'name2'
  end
end
