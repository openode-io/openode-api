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
end
