
require 'test_helper'

class LibTasksDbCleanTest < ActiveSupport::TestCase
  test "should remove old deployments" do
    invoke_task "db_clean:old_deployments"

    global_stat = GlobalStat.first

    assert_equal global_stat.obj['nb_archived_deployments'], 1

    nb_too_old = Execution.where('created_at < ?', 31.days.ago).count
    assert_equal nb_too_old, 0

    assert_equal Execution.where('created_at < ?', 29.days.ago).count, 1
  end

  test "should not remove latest successful deployment" do
    Execution.destroy_all

    w = default_website

    latest_deployment = Deployment.create(
      website: w,
      status: 'success',
      created_at: 34.days.ago
    )
    latest_deployment.status = 'success'
    latest_deployment.save!

    latest_deployment_2 = Deployment.create(
      website: w,
      status: 'success',
      created_at: 32.days.ago
    )

    latest_deployment_2.status = 'success'
    latest_deployment_2.save!

    invoke_task "db_clean:old_deployments"

    assert Deployment.find(latest_deployment_2.id)
    assert_nil Deployment.find_by(id: latest_deployment.id)
  end

  test "should not remove latest successful deployment with old image tag" do
    Execution.destroy_all

    w = default_website

    d_orig = Deployment.create!(
      website: w,
      status: 'success',
      created_at: 34.days.ago
    )

    latest_deployment = Deployment.create(
      website: w,
      status: 'success',
      created_at: 34.days.ago
    )

    latest_deployment.status = 'success'
    latest_deployment.save!

    latest_deployment_2 = Deployment.create(
      website: w,
      status: 'success',
      obj: {
        image_name_tag: "r/asdf--#{d_orig.id}"
      },
      created_at: 32.days.ago
    )

    latest_deployment_2.status = 'success'
    latest_deployment_2.save!

    invoke_task "db_clean:old_deployments"

    assert Deployment.find(latest_deployment_2.id)
    assert Deployment.find(d_orig.id)
    assert_nil Deployment.find_by(id: latest_deployment.id)
  end

  test "should remove too old deployment if not online" do
    Execution.destroy_all

    w = default_website
    w.status = 'N/A'
    w.save!

    d_orig = Deployment.create!(
      website: w,
      status: 'success',
      created_at: 62.days.ago
    )

    latest_deployment = Deployment.create(
      website: w,
      status: 'success',
      created_at: 34.days.ago
    )

    latest_deployment.status = 'success'
    latest_deployment.save!

    invoke_task "db_clean:old_deployments"

    assert Deployment.find(latest_deployment.id)
    assert_nil Deployment.find_by(id: d_orig.id)
  end

  test "should remove if too old deployment and online" do
    Execution.destroy_all

    w = default_website
    w.status = 'online'
    w.save!

    d_orig = Deployment.create!(
      website: w,
      status: 'success',
      created_at: 64.days.ago
    )

    not_latest_deployment = Deployment.create(
      website: w,
      status: 'success',
      created_at: 32.days.ago
    )

    not_latest_deployment.status = 'success'
    not_latest_deployment.save!

    invoke_task "db_clean:old_deployments"

    assert Deployment.find_by(id: not_latest_deployment.id)
    assert_nil Deployment.find_by(id: d_orig.id)
  end

  test "should not remove if too old deployment and online and only one" do
    Execution.destroy_all

    w = default_website
    w.status = 'online'
    w.save!

    d_orig = Deployment.create!(
      website: w,
      status: 'success',
      created_at: 64.days.ago
    )
    d_orig.status = 'success'
    d_orig.save!

    invoke_task "db_clean:old_deployments"

    assert Deployment.find_by(id: d_orig.id)
  end

  test "should remove old task executions" do
    Task.create!(created_at: 2.days.ago, status: 'success')
    deployment = Deployment.create!(created_at: 2.days.ago, status: 'success')
    query_too_old = Execution.not_types(['Deployment'])
                             .where('created_at < ?', 1.day.ago)

    nb_too_old = query_too_old.count

    invoke_task "db_clean:old_task_executions"

    assert_equal nb_too_old - 1, query_too_old.count
    assert deployment.reload
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
