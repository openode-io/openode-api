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
    gke_traffic_limit = (ENV['GKE_TRAFFIC_LIMIT_PER_HOUR'] || '400000000').to_f

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

      def update_traffic(latest_key, tx_type, new_bytes, opts = {})
        if latest_key.present?
          latest_recv = opts[:redis].get(latest_key).to_f

          new_rcv = new_bytes.to_f - latest_recv

          website = opts[:website_location].website
          wl = opts[:website_location]
          ts = opts[:ts]
          k = "traffic--#{wl.id}--#{tx_type}--#{website.site_name}--#{ts}"
          Rails.logger.info "Writing #{k} -> #{new_rcv}"

          opts[:redis].set(k, new_rcv, ex: opts[:expiration])
        end
      end

      update_traffic(latest_key_recv, "rcv",
                     eth0_result["rcv_bytes"],
                     redis: redis,
                     ts: ts,
                     expiration: expiration,
                     website_location: website_location)
      update_traffic(latest_key_tx, "tx",
                     eth0_result["tx_bytes"],
                     redis: redis,
                     ts: ts,
                     expiration: expiration,
                     website_location: website_location)

      keys_site = redis.keys("traffic--#{website_location.id}--rcv--*") +
                  redis.keys("traffic--#{website_location.id}--tx--*")

      sum_traffic = redis.mget(keys_site).map(&:to_f).sum
      w.data ||= {}

      orig_traffic_limit_reached = w.data["traffic_limit_reached"]
      w.data["traffic_limit_reached"] = sum_traffic >= gke_traffic_limit

      if w.data["traffic_limit_reached"]
        Rails.logger.info "Limit traffic reached for #{w.site_name}!"
      end

      if orig_traffic_limit_reached != w.data["traffic_limit_reached"]
        website_location.load_balancer_synced = false
        website_location.save
      end

      w.save

    rescue StandardError => e
      Rails.logger.error("Issue with website=#{w.site_name}, #{e}")
    end
  end
end
