require "redis"

def first_build_server_configs(build_server)
  {
    host: build_server['ip'],
    secret: {
      user: build_server['user'],
      private_key: build_server['private_key']
    }
  }
end

def deployment_method
  manager = CloudProvider::Manager.instance

  build_server_configs = first_build_server_configs(
    manager.application['docker']['build_servers'].first
  )

  runner = DeploymentMethod::Runner.new(
    Website::TYPE_GCLOUD_RUN,
    "gcloud",
    build_server_configs.merge(location: nil)
  )

  dep_method = DeploymentMethod::GcloudRun.new
  dep_method.runner = runner

  dep_method
end

namespace :gcloud_run_maintenance do
  desc ''
  task clean_services: :environment do
    name = TASK_NAME
    Rails.logger.info "[#{name}] begin"

    dep_method = deployment_method

    subcommand_services_list = "run services list --format json"
    services_list = JSON.parse(dep_method.ex("gcloud_cmd",
                                             website: true,
                                             website_location: true,
                                             chg_dir_workspace: false,
                                             subcommand: subcommand_services_list)[:stdout])

    services_list.each do |service|
      site_id = service.dig("metadata", "name").split("-").last.to_i

      website = Website.find_by(id: site_id)

      next if website.blank?

      if website.status == Website::STATUS_OFFLINE
        Rails.logger.info "[#{name}] will remove instance #{website.site_name} "

        website_location = website.website_locations.first
        subcommand_del = "run services delete #{dep_method.service_id(website)} " \
          "--region #{dep_method.region_of(website_location)} --quiet"
        dep_method.ex("gcloud_cmd",
                      website: true,
                      website_location: true,
                      chg_dir_workspace: false,
                      subcommand: subcommand_del)
      end
    rescue StandardError => e
      Ex::Logger.error(e, "[#{name}] Issue processing service #{service.inspect}")
    end
  end

  desc ''
  task collect_gke_traffic: :environment do
    name = "collect_gke_traffic"
    Rails.logger.info "[#{name}] begin"
    redis = Redis.new(url: ENV["REDIS_URL_GKE_TRAFFIC"])

    dep_method = deployment_method

    websites = Website.where(status: 'online')

    websites.each do |w|
      website_location = w.website_locations.first

      if (w.configs || {})["EXECUTION_LAYER"] != "kubernetes"

        next
      end

      pods_json = dep_method.get_pods_json(
        website: w, website_location: w.website_locations.first
      )

      pod_name = dep_method.get_latest_pod_name_in(pods_json)

      args = {
        website: w,
        website_location: website_location,
        with_namespace: true,
        s_arguments: "exec #{pod_name} -- cat /proc/net/dev"
      }
      proc_dev_net_content = dep_method.ex("kubectl_cmd", args)[:stdout]

      result = Io::Net.parse_proc_net_dev(proc_dev_net_content)
      eth0_result = result.select { |r| r["interface"] == "eth0" }.first

      ts = Time.now.getutc.to_i
      expiration = 60 * 60

      latest_key_recv = redis.keys("traffic--#{website_location.id}--raw-rcv--*").max
      latest_key_tx = redis.keys("traffic--#{website_location.id}--raw-tx--*").max

      redis.set("traffic--#{website_location.id}--raw-rcv--#{w.site_name}--#{ts}",
                eth0_result["rcv_bytes"],
                ex: expiration)
      redis.set("traffic--#{website_location.id}--raw-tx--#{w.site_name}--#{ts}",
                eth0_result["tx_bytes"],
                ex: expiration)

      if latest_key_recv.present?
        latest_recv = redis.get(latest_key_recv).to_f

        new_rcv = eth0_result["rcv_bytes"].to_f - latest_recv

        k = "traffic--#{website_location.id}--rcv--#{w.site_name}--#{ts}"
        Rails.logger.info "Writing #{k} -> #{new_rcv}"

        redis.set(k, new_rcv, ex: expiration)
      end

      if latest_key_tx.present?
        latest_tx = redis.get(latest_key_tx).to_f

        new_tx = eth0_result["tx_bytes"].to_f - latest_tx

        k = "traffic--#{website_location.id}--tx--#{w.site_name}--#{ts}"
        Rails.logger.info "Writing #{k} -> #{new_rcv}"

        redis.set(k, new_tx, ex: expiration)
      end

    rescue StandardError => e
      Rails.logger.error("Issue with website=#{w}, #{e}")
    end
  end
end
