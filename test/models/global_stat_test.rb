require 'test_helper'

class GlobalStatTest < ActiveSupport::TestCase
  test "creates, updates properly" do
    GlobalStat.increase!("nb_executions", 10)

    instance = GlobalStat.first!
    assert_equal instance.obj['nb_executions'], 10

    GlobalStat.increase!("nb_executions", 11)
    instance.reload
    assert_equal instance.obj['nb_executions'], 21
  end

  test "multiple variables keep the same instance" do
    instance_exec = GlobalStat.increase!("nb_executions", 10)
    instance_histories = GlobalStat.increase!("nb_histories", 12)
    instance_histories_second = GlobalStat.increase!("nb_histories", 2)

    instance = GlobalStat.first!
    assert_equal instance, instance_exec
    assert_equal instance_histories, instance
    assert_equal instance_histories_second, instance

    instance.reload
    assert_equal instance.obj['nb_executions'], 10
    assert_equal instance.obj['nb_histories'], 14
  end
end
