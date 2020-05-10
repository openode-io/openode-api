
require 'droplet_kit'

MIN_REQUIRED_MEMORY = 2000

def first_build_server_configs(build_server)
  {
    host: build_server['ip'],
    secret: {
      user: build_server['user'],
      private_key: build_server['private_key']
    }
  }
end

def kube_clusters_runners
  manager = CloudProvider::Manager.instance

  build_server_configs = first_build_server_configs(
    manager.application['docker']['build_servers'].first
  )

  clouds = manager.application['clouds']

  clouds
    .select { |c| c['type'] == 'kubernetes' }
    .map do |cloud|
      cloud['locations'].map do |kube_location|
        location_str_id = kube_location['str_id']
        location = Location.find_by str_id: location_str_id

        DeploymentMethod::Runner.new(
          Website::TYPE_KUBERNETES,
          "cloud",
          build_server_configs.merge(location: location)
        )
      end
    end
    .flatten
end

def retrieve_allocated_mb(cluster_runner, node_name)
  node_describe = cluster_runner.execution_method.ex_stdout(
    "raw_kubectl",
    s_arguments: "describe node #{node_name}"
  ).downcase

  ind = node_describe.index("allocated resources:")

  resources_part = node_describe[ind + "allocated resources:".length..]
  line_mem = resources_part.lines.find { |l| l.include?("memory") }
  requested_mem = line_mem[/\d+/].to_i

  requested_mem
end

# digital ocean
def do_client
  DropletKit::Client.new(access_token: ENV['DO_ACCESS_TOKEN'])
end

def get_cluster(client, cluster_name)
  clusters = client.kubernetes_clusters.all

  clusters.find { |c| c.name == cluster_name }
end

def get_random_node_pool(client, cluster_id)
  client.kubernetes_clusters.node_pools(id: cluster_id).sample
end

namespace :kube_maintenance do
  desc ''
  task scale_clusters: :environment do
    name = "Task kube_maintenance__scale_clusters"
    Rails.logger.info "[#{name}] begin"

    kube_clusters_runners.each do |cluster_runner|
      location = cluster_runner.execution_method.location
      Rails.logger.info "[#{name}] Current location #{location.str_id}"

      result = JSON.parse(cluster_runner.execution_method.ex_stdout(
                            "raw_kubectl",
                            s_arguments: "get nodes -o json"
                          ))

      nodes = result.dig('items')

      nodes_infos = nodes.map do |node|
        Rails.logger.info "[#{name}] allocatable = #{node.dig('status', 'allocatable').inspect}"

        node_name = node.dig('metadata', 'name')
        allocatable_memory_mb = node.dig('status', 'allocatable', 'memory').to_i

        {
          name: node_name,
          allocatable_memory_mb: allocatable_memory_mb,
          requested_memory_mb: retrieve_allocated_mb(cluster_runner, node_name)
        }
      end

      node_with_max_available = nodes_infos.max_by do |n|
        n[:allocatable_memory_mb] - n[:requested_memory_mb]
      end

      Rails.logger.info "[#{name}] node with max mem #{node_with_max_available.inspect}"

      next unless node_with_max_available

      available_memory = node_with_max_available[:allocatable_memory_mb] -
                         node_with_max_available[:requested_memory_mb]

      Rails.logger.info "[#{name}] max available_memory (#{location.str_id}) " \
                        "= #{available_memory}"

      if available_memory < MIN_REQUIRED_MEMORY
        Rails.logger.info "[#{name}] requires scale up!"

        digi_client = do_client
        looking_for_cluster = "k8s-#{location.str_id}"
        cluster = get_cluster(digi_client, looking_for_cluster)

        next unless cluster

        node_pool = get_random_node_pool(digi_client, cluster.id)
        node_pool.count += 1
        digi_client.kubernetes_clusters.update_node_pool(node_pool,
                                                         id: cluster.id,
                                                         pool_id: node_pool.id)
      end
    end
  end
end