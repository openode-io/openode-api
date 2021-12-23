

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
        Rails.logger.info "[#{name}] will remove instance #{website.site_name}"
      end
    rescue StandardError => e
      Ex::Logger.error(e, "[#{name}] Issue processing service #{service.inspect}")
    end
  end
end
