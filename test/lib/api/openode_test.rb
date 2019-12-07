
require 'test_helper'

class ApiOpenodeTest < ActiveSupport::TestCase
  test 'getToken' do
    openode_api = Api::Openode.new(token: nil)

    payload = { email: "mymail@openode.io", password: "1234561!" }
    token = openode_api.execute(:post, '/account/getToken', payload: payload)

    assert_equal token, "123456789123"
  end
end
