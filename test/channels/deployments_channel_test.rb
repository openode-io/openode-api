
require 'test_helper'

class DeploymentsChannelTest < ActionCable::Channel::TestCase
  test 'subscribes with valid deployment' do
    deployment = Deployment.first

    stub_connection(current_user: deployment.website.user)

    subscribe deployment_id: deployment.id
    assert subscription.confirmed?
    assert_has_stream_for deployment
  end

  test 'subscribes with valid deployment but without access' do
    deployment = Deployment.first

    user = User.last

    assert_equal user.websites_with_access.map(&:site_name), %w[testsite testprivatecloud]

    stub_connection(current_user: user)

    subscribe deployment_id: deployment.id
    assert_equal subscription.confirmed?, nil
  end
end
