
require 'test_helper'

class DeploymentsChannelTest < ActionCable::Channel::TestCase
  test 'subscribes with valid deployment' do
    deployment = Deployment.first

    subscribe deployment_id: deployment.id
    assert subscription.confirmed?
    assert_has_stream_for deployment
  end
end
