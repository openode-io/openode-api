
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

  desc ''
  task verify_states_pvcs: :environment do
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
        pvc_name = pvc.dig('metadata', 'name')

        next unless instance_ns?(ns)

        website_id = ns.split('-').last

        Rails.logger.info "[#{name}] checking website id #{website_id}"

        website = Website.find_by id: website_id

        reason = ""

        unless website
          reason += " - no website found "
        end

        different_location = website&.first_location != location

        if website && different_location
          reason += " - location should be " \
                            "#{website&.first_location&.str_id} " \
                            "but is #{location.str_id} "
        end

        # main-pvc check
        if !website.extra_storage? && pvc_name == "main-pvc"
          reason += " - main-pvc should not be present "
        end

        if website && pvc_type(pvc_name) == "addon" && !valid_pvc_addon?(website, pvc_name)
          reason += " - addon pvc #{pvc_name} should not be present "
        end

        # check unnessary PVC
        unless reason.empty?
          Rails.logger.info "[#{name}] should remove PVC in ns #{ns}, " \
                            "pvc = #{pvc_name} - reason = #{reason}"

          result = cluster_runner.execution_method.ex_stdout(
            "raw_kubectl",
            s_arguments: " -n #{ns} delete pvc #{pvc_name} "
          )
          Rails.logger.info "[#{name}] PVC #{pvc_name} destroyed result = #{result}"
        end
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

  def pvc_type(name)
    name == "main-pvc" ? "www" : "addon"
  end

  def valid_pvc_addon?(website, pvc_name)
    # website-addon-11-pvc
    wa_id = pvc_name.delete_prefix("website-addon-").delete_suffix("-pvc")
    wa = WebsiteAddon.find_by id: wa_id

    return false unless wa

    website.website_addons.select(&:online?).include?(wa)
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

      result.dig('items').each do |deployment|
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
  task verify_states_deployments: :environment do
    name = "Task kube_maintenance__verify_states_deployments"
    Rails.logger.info "[#{name}] begin"

    kube_clusters_runners.each do |cluster_runner|
      location = cluster_runner.execution_method.location
      Rails.logger.info "[#{name}] Current location #{location.str_id}"

      result = JSON.parse(cluster_runner.execution_method.ex_stdout(
                            "raw_kubectl",
                            { s_arguments: "get deployments --all-namespaces -o json" },
                            skip_result_storage: true
                          ))

      result.dig('items').each do |deployment|
        ns = deployment.dig('metadata', 'namespace')
        deployment_name = deployment.dig('metadata', 'name')

        next unless instance_ns?(ns)

        website_id = ns.split('-').last

        Rails.logger.info "[#{name}] checking website id #{website_id}"

        website = Website.find_by id: website_id
        reason = ""

        # check unnessary deployment
        unless website
          reason += " - website removed "
        end

        if website&.offline?
          reason += " - website offline "
        end

        # check for location

        different_location = website&.first_location != location

        if website && different_location
          reason += " - location should be " \
                            "#{website&.first_location&.str_id} " \
                            "but is #{location.str_id} "
        end

        # check for addon

        if website && deployment_type(deployment_name) == "addon" &&
           !valid_deployment_addon?(website, deployment_name)
          reason += " - addon #{deployment_name} should be removed "
        end

        unless reason.empty?
          Rails.logger.info "[#{name}] should remove deployment #{deployment_name} in " \
                            "ns #{ns} - #{reason}"

          result = cluster_runner.execution_method.ex_stdout(
            "raw_kubectl",
            s_arguments: " -n #{ns} delete deployment #{deployment_name} "
          )
          Rails.logger.info "[#{name}] deployment #{deployment_name} destroyed result = #{result}"
        end
      end
    ensure
      cluster_runner.execution_method&.destroy_execution
    end
  end

  desc ''
  task auto_manage_memory: :environment do
    name = "Task kube_maintenance__auto_manage_memory"
    Rails.logger.info "[#{name}] begin"

    kube_clusters_runners.each do |cluster_runner|
      location = cluster_runner.execution_method.location
      Rails.logger.info "[#{name}] Current location #{location.str_id}"

      result = JSON.parse(cluster_runner.execution_method.ex_stdout(
                            "raw_kubectl",
                            s_arguments: "get pods --all-namespaces -o json -l app=www"
                          ))
      top_result = cluster_runner.execution_method.ex_stdout(
        "raw_kubectl",
        s_arguments: "top pods -l app=www --all-namespaces"
      )

      (result&.dig('items') || []).each do |pod|
        ns = pod.dig('metadata', 'namespace')

        next unless ns.to_s.start_with?(cluster_runner.execution_method.namespace_of)

        website = cluster_runner.execution_method.website_from_namespace(ns)
        next unless website&.present?

        cluster_runner.execution_method.auto_manage_memory(website, pod, top_result)
      rescue StandardError => e
        Rails.logger.error "[#{name}] skipping in items loop, #{e}"
      end

    ensure
      cluster_runner.execution_method&.destroy_execution
    end
  end
end
