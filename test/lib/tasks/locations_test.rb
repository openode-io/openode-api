
require 'test_helper'

class LibTasksLocationsTest < ActiveSupport::TestCase
  test "should populate locations" do
    WebsiteLocation.all.destroy_all
    LocationServer.all.destroy_all
    Location.all.destroy_all

    invoke_task "locations:populate"

    assert_equal Location.count, 17
    assert_equal Location.exists?(str_id: 'canada2'), true
    assert_equal Location.exists?(str_id: 'dallas-3'), true
    assert_equal Location.exists?(str_id: 'new-jersey-1'), true
  end
end
