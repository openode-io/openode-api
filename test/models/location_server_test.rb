# frozen_string_literal: true

require 'test_helper'

class LocationServerTest < ActiveSupport::TestCase
  test 'canada server' do
    location = Location.find_by! str_id: 'canada'
    assert location.location_servers.length == 1
  end
end
