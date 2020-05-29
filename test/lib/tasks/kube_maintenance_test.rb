require 'test_helper'

class LibKubeMaintenanceTest < ActiveSupport::TestCase
  test "scale clusters - no scaling" do
    cmd_nodes = 'KUBECONFIG=/var/www/openode-api/config/kubernetes/' \
                'production-canada2.yml kubectl get nodes -o json'
    prepare_ssh_session(cmd_nodes, IO.read('test/fixtures/kubernetes/get_nodes.json'))

    cmd_desc_node = 'KUBECONFIG=/var/www/openode-api/config/kubernetes/' \
                    'production-canada2.yml kubectl describe node pool-jetf8t6fc-38akt'
    prepare_ssh_session(cmd_desc_node, IO.read('test/fixtures/kubernetes/desc_node.txt'))

    cmd_nodes = 'KUBECONFIG=/var/www/openode-api/config/kubernetes/' \
                'production-usa.yml kubectl get nodes -o json'
    prepare_ssh_session(cmd_nodes, IO.read('test/fixtures/kubernetes/get_nodes.json'))

    cmd_desc_node = 'KUBECONFIG=/var/www/openode-api/config/kubernetes/' \
                    'production-usa.yml kubectl describe node pool-jetf8t6fc-38akt'
    prepare_ssh_session(cmd_desc_node, IO.read('test/fixtures/kubernetes/desc_node.txt'))

    assert_scripted do
      begin_ssh
      invoke_task "kube_maintenance:scale_clusters"
    end
  end

  test "scale clusters - with scaling" do
    cmd_nodes = 'KUBECONFIG=/var/www/openode-api/config/kubernetes/' \
                'production-canada2.yml kubectl get nodes -o json'
    prepare_ssh_session(cmd_nodes, IO.read('test/fixtures/kubernetes/get_nodes.json'))

    cmd_desc_node = 'KUBECONFIG=/var/www/openode-api/config/kubernetes/' \
                    'production-canada2.yml kubectl describe node pool-jetf8t6fc-38akt'
    prepare_ssh_session(cmd_desc_node, IO.read('test/fixtures/kubernetes/desc_node.txt'))

    cmd_nodes = 'KUBECONFIG=/var/www/openode-api/config/kubernetes/' \
                'production-usa.yml kubectl get nodes -o json'
    prepare_ssh_session(cmd_nodes, IO.read('test/fixtures/kubernetes/get_nodes.json'))

    cmd_desc_node = 'KUBECONFIG=/var/www/openode-api/config/kubernetes/' \
                    'production-usa.yml kubectl describe node pool-jetf8t6fc-38akt'
    prepare_ssh_session(cmd_desc_node, IO.read('test/fixtures/kubernetes/desc_node_scaling.txt'))

    assert_scripted do
      begin_ssh
      invoke_task "kube_maintenance:scale_clusters"
    end
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

      assert_equal Execution.count, 0
    end
  end
end
