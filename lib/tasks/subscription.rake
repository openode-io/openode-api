
namespace :subscription do
  desc ''
  task clean: :environment do
    name = "Task subscription__clean"
    Rails.logger.info "[#{name}] begin"

    statuses = [Website::STATUS_ONLINE, Website::STATUS_STARTING, Website::STATUS_STARTING]
    website_ids = Website.in_statuses(statuses).pluck(:id)
    puts "ids #{website_ids.inspect}"
    subscription_websites_to_del = SubscriptionWebsite.where.not(website_id: website_ids)

    subscription_websites_to_del.each do |subscription_website|
      Rails.logger.info "[#{name}] destroying #{subscription_website}"

      subscription_website.destroy
    end
  end
end
