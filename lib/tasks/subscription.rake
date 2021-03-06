
namespace :subscription do
  desc ''
  task clean: :environment do
    name = "Task subscription__clean"
    Rails.logger.info "[#{name}] begin"

    statuses = [Website::STATUS_ONLINE, Website::STATUS_STARTING, Website::STATUS_STARTING]

    SubscriptionWebsite.all.each do |subscription_website|
      website = subscription_website.website

      if !statuses.include?(website.status) || !website.auto_plan?
        Rails.logger.info "[#{name}] destroying #{subscription_website}"

        subscription_website.destroy
      end
    end
  end

  desc ''
  task check_expirations: :environment do
    name = "Task subscription__check_expirations"
    Rails.logger.info "[#{name}] begin"

    subscriptions = Subscription.where(
      'expires_at IS NOT NULL AND ? > expires_at', Time.zone.now
    )

    subscriptions.each do |subscription|
      Rails.logger.info "[#{name}] expiring subscription"

      subscription.active = false
      subscription.quantity = 0

      subscription.save
    rescue StandardError => e
      Ex::Logger.error(e, 'issue processing expiration check')
    end
  end
end
