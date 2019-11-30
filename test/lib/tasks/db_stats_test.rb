
require 'test_helper'

class LibTasksDbStatsTest < ActiveSupport::TestCase
  test "should calculate online websites" do
    nb = Website.where(status: 'online').count
    invoke_task "db_stats:log_nb_sites_up"

    stat = SystemStat.last

    assert_equal stat.obj['nb_online'], nb
  end
end
