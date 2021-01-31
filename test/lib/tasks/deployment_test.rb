
require 'test_helper'

class LibTasksDeploymentTest < ActiveSupport::TestCase
  test "should stop too old deployment" do
    Execution.destroy_all

    w1 = Website.find_by site_name: 'testsite'
    w1.status = Website::STATUS_ONLINE
    w1.save!
    w2 = Website.find_by site_name: 'testsite2'
    w2.status = Website::STATUS_STOPPING
    w2.save!
    w3 = Website.find_by site_name: 'www.what.is'
    w3.status = Website::STATUS_STARTING
    w3.save!

    w4 = Website.find_by site_name: 'app.what.is'
    w4.status = Website::STATUS_STARTING
    w4.save!

    dep = Deployment.create!(website: w3, status: Deployment::STATUS_RUNNING)

    dep.created_at = Time.zone.now - Deployment::MAX_RUN_TIME - 1.minute
    dep.save!

    Deployment.create!(website: w4, status: Deployment::STATUS_RUNNING)

    invoke_task "deployment:shutdown_neverending_deployments"

    assert_equal w1.reload.status, Website::STATUS_ONLINE
    assert_equal w2.reload.status, Website::STATUS_OFFLINE
    assert_equal w3.reload.status, Website::STATUS_OFFLINE
    assert_equal w4.reload.status, Website::STATUS_STARTING
  end
end
