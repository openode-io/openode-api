
require 'droplet_kit'

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

# digital ocean
def do_client
  DropletKit::Client.new(access_token: ENV['DO_ACCESS_TOKEN'])
end

def instance_ns?(current_namespace)
  current_namespace.starts_with?('instance-')
end

namespace :kube_maintenance do
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
        status = pod['status']
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
        # website_status = WebsiteStatus.log(website, statuses)
        WebsiteStatus.log(website, statuses)

        ###
        # states analysis

        # contains OOMKilled with significant restart count

        # statuses_killed = website_status.statuses_containing_terminated_reason('oomkilled')
        #                                .select do |st|
        #  st['restartCount'] && st['restartCount'] >= 1
        # end

        # if statuses_killed.any?
        #  Rails.logger.info "[#{name}] should kill deployment of " \
        #                    "#{website.site_name} - #{statuses_killed.inspect}"

        #  wl = website.website_locations.first
        #  wl.notify_force_stop('Out of memory detected')

        #  cluster_runner.execution_method.do_stop(
        #    website: website,
        #    website_location: wl
        #  )
        # end
      rescue StandardError => e
        Rails.logger.error "[#{name}] skipping statuses_by_website, #{e}"
      end

    ensure
      cluster_runner.execution_method&.destroy_execution
    end
  end

  def deployment_type(name)
    name == "www-deployment" ? "www" : "addon"
  end

  def valid_deployment_addon?(website, deployment_name)
    addon_names = website.website_addons.select(&:online?).map(&:name)

    addon_names.include?(deployment_name.delete_suffix("-deployment"))
  end

  desc ''
  task clean_ns: :environment do
    name = "Task kube_maintenance__clean_ns"
    Rails.logger.info "[#{name}] begin"

    kube_clusters_runners.each do |cluster_runner|
      location = cluster_runner.execution_method.location
      Rails.logger.info "[#{name}] Current location #{location.str_id}"

      result = JSON.parse(cluster_runner.execution_method.ex_stdout(
                            "raw_kubectl",
                            { s_arguments: "get namespaces -o json" },
                            skip_result_storage: true
                          ))

      result['items'].each do |deployment|
        ns = deployment.dig('metadata', 'name')

        next unless instance_ns?(ns)

        website_id = ns.split('-').last

        Rails.logger.info "[#{name}] checking website id #{website_id}"

        website = Website.find_by id: website_id
        reason = ""

        unless website
          reason += " - website removed "
        end

        if !website&.active? && website&.offline?
          reason += " - website inactive "
        end

        unless reason.empty?
          log_info = "location=#{location.str_id}, reason = #{reason}"
          Rails.logger.info "[#{name}] should remove ns #{ns}, #{log_info}"

          result = cluster_runner.execution_method.ex_stdout(
            "raw_kubectl",
            s_arguments: " delete namespace #{ns} "
          )
          Rails.logger.info "[#{name}] deleted ns #{ns}, result = #{result}"
        end
      end
    end
  end

  desc ''
  task monitor_pods_stats: :environment do
    name = "Task kube_maintenance__monitor_pods_stats"
    Rails.logger.info "[#{name}] begin"

    kube_clusters_runners.each do |cluster_runner|
      location = cluster_runner.execution_method.location
      Rails.logger.info "[#{name}] Current location #{location.str_id}"

      top_raw_result = cluster_runner.execution_method.ex_stdout(
        "raw_kubectl",
        s_arguments: "top pods --all-namespaces"
      )

      top_results = cluster_runner.execution_method.top(top_raw_result)
      websites_results = {}

      top_results.each do |top_result|
        website = cluster_runner.execution_method.website_from_namespace(top_result[:namespace])

        next unless website&.present?

        websites_results[website] ||= []
        websites_results[website] << top_result
      end

      websites_results.each do |website, top_result|
        WebsiteStats.create(website: website, obj: top_result)
      end

    ensure
      cluster_runner.execution_method&.destroy_execution
    end
  end
end
