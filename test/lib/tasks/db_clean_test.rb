
require 'test_helper'

class LibTasksDbCleanTest < ActiveSupport::TestCase
  test "should remove old executions" do
    invoke_task "db_clean:old_executions"

    global_stat = GlobalStat.first

    assert_equal global_stat.obj['nb_archived_deployments'], 1
    assert_equal global_stat.obj['nb_archived_executions'], nil

    nb_too_old = Execution.where('created_at < ?', 31.days.ago).count
    assert_equal nb_too_old, 0

    assert_equal Execution.where('created_at < ?', 29.days.ago).count, 1
  end

  test "should remove old histories" do
    invoke_task "db_clean:old_histories"

    global_stat = GlobalStat.first

    assert_equal global_stat.obj['nb_archived_histories'], 1

    nb_too_old = History.where('created_at < ?', 62.days.ago).count
    assert_equal nb_too_old, 0
  end

  test "should remove old credit_actions" do
    invoke_task "db_clean:old_credit_actions"

    global_stat = GlobalStat.first

    assert_equal global_stat.obj['nb_archived_credit_actions'], 1

    nb_too_old = CreditAction.where('created_at < ?', 45.days.ago).count
    assert_equal nb_too_old, 0
  end
end
