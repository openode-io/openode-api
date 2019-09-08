require 'test_helper'

class StatusTest < ActiveSupport::TestCase
  test "mongo should be up" do
     assert_equal Status.find_by(name: "Mongodb").status, "up"
  end

  test "with status down" do

    down_statuses = Status.with_status("down")

    assert_equal down_statuses.length, 1
    assert_equal down_statuses[0].name, "docker canada"
  end
end
