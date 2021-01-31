require 'test_helper'
require 'test_kubernetes_helper'

class LibKubeMaintenanceTest < ActiveSupport::TestCase
  def prepare_kubernetes_method(website, website_location)
    runner = prepare_kubernetes_runner(website, website_location)

    @kubernetes_method = runner.get_execution_method
  end

  test "monitor pod" do
    WebsiteStatus.all.each(&:destroy)

    website = default_website
    website.status = Website::STATUS_ONLINE
    website.type = Website::TYPE_KUBERNETES
    website.save!

    cmd = "KUBECONFIG=/var/www/openode-api/config/kubernetes/production-canada2.yml " \
          "kubectl get pods --all-namespaces -o json"
    content = IO.read('test/fixtures/kubernetes/1_pod_alive.json')
    prepare_ssh_session(cmd, content.gsub("instance-152", "instance-#{website.id}"))

    cmd = "KUBECONFIG=/var/www/openode-api/config/kubernetes/production-usa.yml " \
          "kubectl get pods --all-namespaces -o json"
    prepare_ssh_session(cmd, IO.read('test/fixtures/kubernetes/empty_pod.json'))

    assert_scripted do
      begin_ssh

      Execution.all.each(&:destroy)

      invoke_task "kube_maintenance:monitor_pods"

      status = website.statuses.last
      statuses = status.simplified_container_statuses

      assert_equal status.ref_id, website.id
      assert_equal statuses.length, 1
      assert_equal statuses.first['name'], "www"

      assert_equal status.obj.length, 1
      assert_equal status.obj.first['label_app'], "www"
      assert_equal status.obj.first.dig('status', 'containerStatuses').length, 1

      assert_equal Execution.count, 0
    end
  end

  # test "monitor pod - with oomkilled" do
  #  StopWebsiteEvent.destroy_all

  #  website = default_website
  #  website.status = Website::STATUS_ONLINE
  #  website.type = Website::TYPE_KUBERNETES
  #  website.save!

  #  website_location = website.website_locations.first

  #  prepare_kubernetes_method(website, website_location)

  #  cmd = "KUBECONFIG=/var/www/openode-api/config/kubernetes/production-canada2.yml " \
  #        "kubectl get pods --all-namespaces -o json"
  #  content = IO.read('test/fixtures/kubernetes/pods_with_oom_killed.json')
  #              .gsub("instance-152", "instance-#{website.id}")

  #  prepare_ssh_session(cmd, content)

  #  prepare_make_secret(@kubernetes_method, website, website_location, "result")
  #  prepare_get_dotenv(@kubernetes_method, website, "VAR1=12")

  #  prepare_action_yml(@kubernetes_method, website_location, "apply.yml",
  #                     "delete -f apply.yml", 'success')

  #  cmd = "KUBECONFIG=/var/www/openode-api/config/kubernetes/production-usa.yml " \
  #        "kubectl get pods --all-namespaces -o json"
  #  prepare_ssh_session(cmd, IO.read('test/fixtures/kubernetes/empty_pod.json'))

  #  assert_scripted do
  #    begin_ssh

  #    invoke_task "kube_maintenance:monitor_pods"

  #    assert_equal website.reload.status, 'online'
  #    assert_includes website.stop_events.last.obj['reason'], 'Out of memory'
  #  end
  # end
end
