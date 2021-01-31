
namespace :deployment do
  desc ''
  task shutdown_neverending_deployments: :environment do
    task_name = "Task deployment__shutdown_neverending_deployments"
    Rails.logger.info "[#{task_name}] begin"

    mutating_websites = Website.where(status: Website::MUTATING_STATUSES)

    mutating_websites.each do |website|
      Rails.logger.info "[#{task_name}] checking #{website.site_name}"

      latest_deployment = website.deployments.last

      if !latest_deployment ||
         latest_deployment.created_at < Time.zone.now - Deployment::MAX_RUN_TIME
        Rails.logger.info "[#{task_name}] " \
                          "too long deployment detected for #{website.site_name}"
        website.status = Website::STATUS_OFFLINE
        website.save(validate: false)
      end
    rescue StandardError => e
      Ex::Logger.error(e, "Issue with website shutdown #{website.site_name}")
    end
  end
end
