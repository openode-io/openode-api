require 'test_helper'
require 'test_kubernetes_helper'

class LibMonitorDeploymentsTest < ActiveSupport::TestCase
  test "monitor deployments - with one online" do
    Website.all.each do |w|
      w.status = Website::STATUS_OFFLINE
      w.save!
    end

    WebsiteStatus.all.each(&:destroy)

    website = default_website
    website.status = Website::STATUS_ONLINE
    website.type = Website::TYPE_KUBERNETES
    website.save!

    cmd = get_kubernetes_method(website).kubectl(
      website_location: website.website_locations.first,
      with_namespace: true,
      s_arguments: "get pods -o json"
    )

    prepare_ssh_session(cmd, IO.read('test/fixtures/kubernetes/1_pod_alive.json'))

    assert_scripted do
      begin_ssh
      invoke_task "monitor_deployments:pod_status"

      status = website.statuses.last
      statuses = status.simplified_container_statuses

      assert_equal status.ref_id, website.id
      assert_equal statuses.length, 1
      assert_equal statuses.first['name'], "www"
    end
  end

  test "monitor deployments - with one online without status" do
    Website.all.each do |w|
      w.status = Website::STATUS_OFFLINE
      w.save!
    end

    WebsiteStatus.all.each(&:destroy)

    website = default_website
    website.status = Website::STATUS_ONLINE
    website.type = Website::TYPE_KUBERNETES
    website.save!

    cmd = get_kubernetes_method(website).kubectl(
      website_location: website.website_locations.first,
      with_namespace: true,
      s_arguments: "get pods -o json"
    )

    prepare_ssh_session(cmd, IO.read('test/fixtures/kubernetes/empty_pod.json'))

    assert_scripted do
      begin_ssh
      invoke_task "monitor_deployments:pod_status"

      assert_equal website.statuses.length, 1
      assert_equal website.statuses.first.obj, nil
    end
  end

  test "monitor deployments - without any online" do
    Website.all.each do |w|
      w.status = Website::STATUS_OFFLINE
      w.save!
    end

    WebsiteStatus.all.each(&:destroy)

    invoke_task "monitor_deployments:pod_status"

    assert_equal WebsiteStatus.count, 0
  end
end
