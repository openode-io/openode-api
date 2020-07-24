require 'test_helper'
require 'test_kubernetes_helper'

class LibMonitorDeploymentsTest < ActiveSupport::TestCase
  def prepare_get_pods_happy(kubernetes_method, website_location)
    cmd = kubernetes_method.kubectl(
      website_location: website_location,
      with_namespace: true,
      s_arguments: "get pods -o json"
    )

    prepare_ssh_session(cmd, IO.read('test/fixtures/kubernetes/1_pod_alive.json'))
  end

  test "monitor deployments bandwidth - happy path with previous week network stats" do
    Website.all.each do |w|
      w.status = Website::STATUS_OFFLINE
      w.save!
    end

    w = default_website
    w.change_status!(Website::STATUS_ONLINE)
    w.type = Website::TYPE_KUBERNETES
    w.save!

    WebsiteBandwidthDailyStat.all.each(&:destroy)

    WebsiteBandwidthDailyStat.create(
      website: w,
      obj: {
        "previous_network_metrics" => {
          'www-deployment-5889df69dc-xg9xl': [
            {
              "interface" => "eth0",
              "rcv_bytes" => 84_363_193.0 - 1000,
              "tx_bytes" => 9_758_564.0 - 100
            }
          ]
        },
        "rcv_bytes" => 100.0,
        "tx_bytes" => 10.0
      },
      created_at: Time.zone.now - 1.week,
      updated_at: Time.zone.now - 1.week
    )

    kubernetes_method = get_kubernetes_method(w)

    prepare_get_pods_happy(kubernetes_method, w.website_locations.first)

    cmd = kubernetes_method.kubectl(
      website_location: w.website_locations.first,
      with_namespace: true,
      s_arguments: "exec www-deployment-5889df69dc-xg9xl -- cat /proc/net/dev"
    )

    # new proc net is
    # {
    #   "interface" => "eth0",
    #   "rcv_bytes" => 84363193.0,
    #   "tx_bytes" => 9758564.0
    # }
    prepare_ssh_session(cmd, IO.read('test/fixtures/net/proc_net_dev/1'))

    assert_scripted do
      begin_ssh

      Execution.all.each(&:destroy)
      assert_equal Execution.count, 0

      invoke_task "monitor_deployments:bandwidth"

      stat = WebsiteBandwidthDailyStat.last

      assert_equal stat.ref_id, w.id

      expected_pod_name = 'www-deployment-5889df69dc-xg9xl'

      assert_equal stat.obj['previous_network_metrics'][expected_pod_name].length, 1

      pod_result = stat.obj['previous_network_metrics'][expected_pod_name]
      assert_equal pod_result.first['interface'], 'eth0'
      assert_equal pod_result.first['rcv_bytes'], 84_363_193.0
      assert_equal pod_result.first['tx_bytes'], 9_758_564
      assert_equal stat.obj['rcv_bytes'], 1000
      assert_equal stat.obj['tx_bytes'], 100

      assert_equal Execution.count, 0
    end
  end

  test "monitor deployments bandwidth - happy path reusing today network stats" do
    Website.all.each do |w|
      w.status = Website::STATUS_OFFLINE
      w.save!
    end

    w = default_website
    w.change_status!(Website::STATUS_ONLINE)
    w.type = Website::TYPE_KUBERNETES
    w.save!

    WebsiteBandwidthDailyStat.all.each(&:destroy)

    today_stat = WebsiteBandwidthDailyStat.create(
      website: w,
      obj: {
        "previous_network_metrics" => {
          'www-deployment-5889df69dc-xg9xl': [
            {
              "interface" => "eth0",
              "rcv_bytes" => 84_363_193.0 - 1000,
              "tx_bytes" => 9_758_564.0 - 100
            }
          ]
        },
        "rcv_bytes" => 100.0,
        "tx_bytes" => 10.0
      }
    )

    kubernetes_method = get_kubernetes_method(w)

    prepare_get_pods_happy(kubernetes_method, w.website_locations.first)

    cmd = kubernetes_method.kubectl(
      website_location: w.website_locations.first,
      with_namespace: true,
      s_arguments: "exec www-deployment-5889df69dc-xg9xl -- cat /proc/net/dev"
    )

    # new proc net is
    # {
    #   "interface" => "eth0",
    #   "rcv_bytes" => 84363193.0,
    #   "tx_bytes" => 9758564.0
    # }
    prepare_ssh_session(cmd, IO.read('test/fixtures/net/proc_net_dev/1'))

    assert_scripted do
      begin_ssh

      invoke_task "monitor_deployments:bandwidth"

      stat = WebsiteBandwidthDailyStat.last

      assert_equal today_stat.id, stat.id

      assert_equal stat.ref_id, w.id

      expected_pod_name = 'www-deployment-5889df69dc-xg9xl'
      pod_result = stat.obj['previous_network_metrics'][expected_pod_name]

      assert_equal pod_result.length, 1
      assert_equal pod_result.first['interface'], 'eth0'
      assert_equal pod_result.first['rcv_bytes'], 84_363_193.0
      assert_equal pod_result.first['tx_bytes'], 9_758_564
      assert_equal stat.obj['rcv_bytes'], 1000 + 100
      assert_equal stat.obj['tx_bytes'], 100 + 10
    end
  end

  test "monitor deployments bandwidth - with exceeding traffic" do
    Website.all.each do |w|
      w.status = Website::STATUS_OFFLINE
      w.save!
    end

    w = default_website
    w.change_status!(Website::STATUS_ONLINE)
    w.type = Website::TYPE_KUBERNETES
    w.save!

    WebsiteBandwidthDailyStat.all.each(&:destroy)
    CreditAction.all.each(&:destroy)

    WebsiteBandwidthDailyStat.create(
      website: w,
      obj: {
        "previous_network_metrics" => {
          'www-deployment-5889df69dc-xg9xl': [
            {
              "interface" => "eth0",
              "rcv_bytes" => 84_363_193.0 - 1000,
              "tx_bytes" => 9_758_564.0 - 100
            }
          ]
        },
        "rcv_bytes" => 200_000_000_000.0,
        "tx_bytes" => 1_000_000_000.0
      }
    )

    kubernetes_method = get_kubernetes_method(w)

    prepare_get_pods_happy(kubernetes_method, w.website_locations.first)

    cmd = kubernetes_method.kubectl(
      website_location: w.website_locations.first,
      with_namespace: true,
      s_arguments: "exec www-deployment-5889df69dc-xg9xl -- cat /proc/net/dev"
    )

    prepare_ssh_session(cmd, IO.read('test/fixtures/net/proc_net_dev/1'))

    assert_scripted do
      begin_ssh

      invoke_task "monitor_deployments:bandwidth"

      c = CreditAction.last

      expected_cost =
        100 * CloudProvider::Helpers::Pricing.cost_for_extra_bandwidth_bytes(1100)

      assert_equal c.action_type, 'consume-bandwidth'
      assert_in_delta c.credits_spent, expected_cost, 0.000001
    end
  end
end
