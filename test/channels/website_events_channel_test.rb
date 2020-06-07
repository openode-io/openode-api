
require 'test_helper'

class WebsiteEventsChannelTest < ActionCable::Channel::TestCase
  test 'subscribes with valid website' do
    w = default_website

    stub_connection(current_user: w.user)

    subscribe website_id: w.id
    assert subscription.confirmed?
    assert_has_stream_for WebsiteEventsChannel.full_id_channel(w)
  end
end
