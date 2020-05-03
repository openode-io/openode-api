
namespace :verify_website_environment do
  desc ''
  task open_source_activated: :environment do
    task_name = "Task verify_website_environment__open_source_activated"
    Rails.logger.info "[#{task_name}] begin"

    websites = Website
               .in_statuses([Website::STATUS_ONLINE])
               .where(open_source_activated: true)

    websites.each do |w|
      os_valid = w.validate_open_source rescue false

      unless os_valid
        Rails.logger.info "[#{task_name}] deactivating website #{w.site_name}"
        w.open_source_activated = false
        w.save(validate: false)
      end
    rescue StandardError => e
      Ex::Logger.error(e, "[#{task_name}] failed with website #{w.site_name}")
    end
  end
end
