require 'test_helper'

class LocationServerTest < ActiveSupport::TestCase
  test "canada server" do
    location = Location.find_by! str_id: "canada"
    assert location.location_servers[0].ip == "127.0.0.1"
  end
end
