
require 'test_helper'

class LibTasksUpdateUptimeRobotTest < ActiveSupport::TestCase
  test "uptime robot" do
    Status.all.destroy_all
    invoke_task "update:uptime_robot"

    assert_equal Status.all.count, 12

    all_up = Status.all.all? { |s| s.status == "up" }
    assert_equal all_up, true

    first_monitor = Status.first

    assert_equal first_monitor.name, "Cloud Hosting (Canada - America)"
  end
end
