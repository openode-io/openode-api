
namespace :monitor_deployments do
  desc ''
  task pod_status: :environment do
    name = "Task monitor_deployments__pod_status"
    Rails.logger.info "[#{name}] begin"

    websites = Website
               .in_statuses([Website::STATUS_ONLINE])
               .where(type: Website::TYPE_KUBERNETES)

    websites.each do |website|
      Rails.logger.info "[#{name}] current website #{website.site_name}"
      wl = website.website_locations.first

      exec_method = wl.prepare_runner.get_execution_method

      result = exec_method.get_pods_json(website: website, website_location: wl)

      status = result&.dig('items')&.first&.dig('status')

      WebsiteStatus.log(website, status)
    rescue StandardError => e
      Ex::Logger.error(e, "[#{name}] failed with website #{website.site_name}")
    end
  end
end
