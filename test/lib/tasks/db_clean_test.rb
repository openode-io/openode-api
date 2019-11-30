
require 'test_helper'

class LibTasksDbCleanTest < ActiveSupport::TestCase
  test "should remove old executions" do
    invoke_task "db_clean:old_executions"

    global_stat = GlobalStat.first

    assert_equal global_stat.obj['nb_archived_executions'], 1

    nb_too_old = Execution.where('created_at < ?', 31.days.ago).count
    assert_equal nb_too_old, 0

    assert_equal Execution.where('created_at < ?', 29.days.ago).count, 1
  end
end