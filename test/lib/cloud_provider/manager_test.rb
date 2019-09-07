require 'test_helper'

class ManagerTest < ActiveSupport::TestCase

  def setup
    CloudProvider::Manager.clear_instance
  end

  test "instance initializes" do
    manager = CloudProvider::Manager.instance

    assert_equal manager, CloudProvider::Manager.instance

    # should have initialized the canada2 test
    location = Location.find_by! str_id: "canada2"
    assert_equal location.present?, true
    assert_equal location.str_id, "canada2"
    assert_equal location.full_name, "Montreal (Canada2)"
    assert_equal location.country_fullname, "Canada2"
  end

  test "available locations" do
    locations = CloudProvider::Manager.instance.available_locations

    assert_equal locations.length, 3
    assert_equal locations[0][:id], "canada"
    assert_equal locations[1][:id], "canada2"
    assert_equal locations[2][:id], "usa"
  end

end
