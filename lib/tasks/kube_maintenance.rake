
require 'droplet_kit'

MIN_REQUIRED_MEMORY = 2000
MAX_PODS_PER_NODE = 110

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

def retrieve_nb_pods_in_node(cluster_runner, node_name)
  get_pods_result = JSON.parse(cluster_runner.execution_method.ex_stdout(
                                 "raw_kubectl",
                                 s_arguments: "get pods --all-namespaces " \
                                              "-o wide --field-selector " \
                                              "spec.nodeName=#{node_name} -o json"
                               ))

  get_pods_result&.dig('items')&.count || 0
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

def get_node_pool_size_mb(node_pool)
  # size looks like: s-6vcpu-16gb

  size_parts = node_pool.size.split("-")

  size_parts.last&.include?("gb") ? size_parts.last.to_i * 1000 : nil
end

def should_scale_down_cluster?(total_available_ram_mb, diff_change_mb)
  (total_available_ram_mb - (diff_change_mb.to_f * 0.75)) > MIN_REQUIRED_MEMORY * 2.0
end

def instance_ns?(current_namespace)
  current_namespace.starts_with?('instance-')
end

def scale_down_move_strategy(name, total_available_ram_mb, _digi_client, cluster, node_pools)
  max_node_pool = node_pools.max_by do |node_pool|
    node_pool.count <= 0 ? 0 : (get_node_pool_size_mb(node_pool) || 0)
  end

  unless max_node_pool
    Rails.logger.info "[#{name}] no max node pool for MOVE strategy"
  end

  if max_node_pool
    smaller_node_pool = node_pools.find do |node_pool|
      get_node_pool_size_mb(node_pool) && get_node_pool_size_mb(max_node_pool) &&
        get_node_pool_size_mb(node_pool) < get_node_pool_size_mb(max_node_pool)
    end

    if smaller_node_pool
      Rails.logger.info "[#{name}] found smaller node pool for MOVE " \
                        "#{smaller_node_pool.name}"

      diff_max_pool_vs_small = get_node_pool_size_mb(max_node_pool) -
                               get_node_pool_size_mb(smaller_node_pool)

      Rails.logger.info "[#{name}] for MOVE " \
                        "diff_max_pool_vs_small = #{diff_max_pool_vs_small}"

      if should_scale_down_cluster?(total_available_ram_mb, diff_max_pool_vs_small)
        Rails.logger.info "[#{name}] ACTION_TAKEN should scale down using MOVE strategy!"
        History.create(obj: {
                         "title": "can scale down - move cluster #{cluster.id} node pools.",
                         "max_node_pool_to_reduce": max_node_pool.name,
                         "smaller_node_pool_to_increase": smaller_node_pool.name,
                         "total_available_ram_mb": total_available_ram_mb,
                         "diff_max_pool_vs_small": diff_max_pool_vs_small
                       })

        true
      else
        Rails.logger.info "[#{name}] for MOVE should not scale down"
      end
    end
  end
end

def scale_down_decrease_strategy(name, total_available_ram_mb, _digi_client,
                                 cluster, node_pools)
  node_pool_to_decrease = node_pools.find do |node_pool|
    diff_remove_node_mb = get_node_pool_size_mb(node_pool)
    should_scale_down_cluster?(total_available_ram_mb, diff_remove_node_mb) &&
      node_pool.count.positive?
  end

  if node_pool_to_decrease
    Rails.logger.info "[#{name}] ACTION_TAKEN can scale down using DECREASE strategy!"
    History.create(obj: {
                     "title": "can scale down - decrease cluster #{cluster.id} node pools.",
                     "node_pool_to_decrease": node_pool_to_decrease.name,
                     "total_available_ram_mb": total_available_ram_mb
                   })
  else
    Rails.logger.info "[#{name}] no node pool found for DECREASE strategy!"
  end
end

namespace :kube_maintenance do
  desc ''
  task scale_clusters: :environment do
    name = "Task kube_maintenance__scale_clusters"
    Rails.logger.info "[#{name}] begin"

    kube_clusters_runners.each do |cluster_runner|
      location = cluster_runner.execution_method.location
      digi_client = do_client
      cluster_name = "k8s-#{location.str_id}"
      cluster = get_cluster(digi_client, cluster_name)

      next unless cluster

      Rails.logger.info "[#{name}] Current location #{location.str_id} - " \
                        "cluster #{cluster_name}"

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
          requested_memory_mb: retrieve_allocated_mb(cluster_runner, node_name),
          nb_pods: retrieve_nb_pods_in_node(cluster_runner, node_name)
        }
      end

      node_with_max_available = nodes_infos.max_by do |n|
        if n[:nb_pods] >= MAX_PODS_PER_NODE
          # hard set of requested_memory_mb to max alloc to force having no memory
          n[:orig_requested_memory_mb] = n[:requested_memory_mb]
          n[:requested_memory_mb] = n[:allocatable_memory_mb]
        end

        n[:allocatable_memory_mb] - n[:requested_memory_mb]
      end

      Rails.logger.info "[#{name}] node with max mem #{node_with_max_available.inspect}"

      next unless node_with_max_available

      available_memory = node_with_max_available[:allocatable_memory_mb] -
                         node_with_max_available[:requested_memory_mb]

      Rails.logger.info "[#{name}] max available_memory (#{location.str_id}) " \
                        "= #{available_memory}"

      if available_memory < MIN_REQUIRED_MEMORY
        Rails.logger.info "[#{name}] ACTION_TAKEN requires scale up!"

        pool = get_random_node_pool(digi_client, cluster.id)
        pool.count += 1
        digi_client.kubernetes_clusters.update_node_pool(pool,
                                                         id: cluster.id,
                                                         pool_id: pool.id)
        History.create(obj: {
                         "title": "increasing cluster #{cluster.id} nb nodes to #{pool.count}"
                       })
      else
        total_available_ram_mb = nodes_infos
                                 .map { |n| n[:allocatable_memory_mb] - n[:requested_memory_mb] }
                                 .sum

        node_pools = digi_client.kubernetes_clusters.node_pools(id: cluster.id)

        # 1- DECREASE - case one node pool nb nodes can just be reduced
        scale_down_decrease_strategy(name, total_available_ram_mb, digi_client,
                                     cluster, node_pools)

        # 2- MOVE - case two, we can reduce a big node pool, and add 1 to a
        # small node pool
        scale_down_move_strategy(name, total_available_ram_mb, digi_client,
                                 cluster, node_pools)
      end
    end
  end

  desc ''
  task monitor_pods: :environment do
    name = "Task kube_maintenance__monitor_pods"
    Rails.logger.info "[#{name}] begin"

    kube_clusters_runners.each do |cluster_runner|
      location = cluster_runner.execution_method.location
      Rails.logger.info "[#{name}] Current location #{location.str_id}"

      result = JSON.parse(cluster_runner.execution_method.ex_stdout(
                            "raw_kubectl",
                            s_arguments: "get pods --all-namespaces -o json"
                          ))

      statuses_by_website = {}

      (result&.dig('items') || []).each do |pod|
        ns = pod.dig('metadata', 'namespace')
        status = pod.dig('status')
        label_app = pod.dig('metadata', 'labels', 'app')

        next unless ns.to_s.start_with?(cluster_runner.execution_method.namespace_of)

        website = cluster_runner.execution_method.website_from_namespace(ns)
        next unless website&.present?

        statuses_by_website[website] ||= []

        statuses_by_website[website] << {
          label_app: label_app,
          status: status
        }
      rescue StandardError => e
        Rails.logger.error "[#{name}] skipping in items loop, #{e}"
      end

      statuses_by_website.each do |website, statuses|
        Rails.logger.info "[#{name}] logging status for #{website.site_name}"
        website_status = WebsiteStatus.log(website, statuses)

        ###
        # states analysis

        # contains OOMKilled with significant restart count

        statuses_killed = website_status.statuses_containing_terminated_reason('oomkilled')
                                        .select do |st|
          st['restartCount'] && st['restartCount'] >= 2
        end

        if statuses_killed.any?
          Rails.logger.info "[#{name}] should kill deployment of " \
                            "#{website.site_name} - #{statuses_killed.inspect}"

          wl = website.website_locations.first
          wl.notify_force_stop('Out of memory detected')

          cluster_runner.execution_method.do_stop(
            website: website,
            website_location: wl
          )
        end
      rescue StandardError => e
        Rails.logger.error "[#{name}] skipping statuses_by_website, #{e}"
      end

    ensure
      cluster_runner.execution_method&.destroy_execution
    end
  end

  # TODO: add tests
  desc ''
  task verify_states_main_pvc: :environment do
    name = "Task kube_maintenance__verify_states_main_pvc"
    Rails.logger.info "[#{name}] begin"

    kube_clusters_runners.each do |cluster_runner|
      location = cluster_runner.execution_method.location
      Rails.logger.info "[#{name}] Current location #{location.str_id}"

      # PVC check
      result = JSON.parse(cluster_runner.execution_method.ex_stdout(
                            "raw_kubectl",
                            s_arguments: "get pvc --all-namespaces -o json"
                          ))

      result.dig('items').each do |pvc|
        ns = pvc.dig('metadata', 'namespace')

        next unless instance_ns?(ns)

        website_id = ns.split('-').last

        Rails.logger.info "[#{name}] checking website id #{website_id}"

        website = Website.find_by id: website_id

        different_location = website&.first_location != location

        if different_location
          Rails.logger.info "[#{name}] reason: " \
                            "location should be " \
                            "#{website&.first_location&.str_id} " \
                            "but is #{location.str_id}"
        end

        # check unnessary PVC
        if !website || !website.extra_storage? || different_location
          Rails.logger.info "[#{name}] should remove PVC in ns #{ns}"
        end
      end
    ensure
      cluster_runner.execution_method&.destroy_execution
    end
  end

  # TODO add tests
  desc ''
  task verify_states_deployments: :environment do
    name = "Task kube_maintenance__verify_states_deployments"
    Rails.logger.info "[#{name}] begin"

    kube_clusters_runners.each do |cluster_runner|
      location = cluster_runner.execution_method.location
      Rails.logger.info "[#{name}] Current location #{location.str_id}"

      result = JSON.parse(cluster_runner.execution_method.ex_stdout(
                            "raw_kubectl",
                            s_arguments: "get deployments --all-namespaces -o json"
                          ))

      result.dig('items').each do |deployment|
        ns = deployment.dig('metadata', 'namespace')

        next unless instance_ns?(ns)

        website_id = ns.split('-').last

        Rails.logger.info "[#{name}] checking website id #{website_id}"

        website = Website.find_by id: website_id

        # check unnessary deployment
        unless website
          Rails.logger.info "[#{name}] reason: website removed"
        end

        if website&.offline?
          Rails.logger.info "[#{name}] reason: website offline"
        end

        different_location = website&.first_location != location

        if different_location
          Rails.logger.info "[#{name}] reason: " \
                            "location should be " \
                            "#{website&.first_location&.str_id} " \
                            "but is #{location.str_id}"
        end

        if !website || website.offline? || different_location
          Rails.logger.info "[#{name}] should remove deployment in ns #{ns}"
        end
      end
    ensure
      cluster_runner.execution_method&.destroy_execution
    end
  end
end
