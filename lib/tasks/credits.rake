
namespace :credits do
  desc ''
  task spend: :environment do
    puts "start spend.."
    name = "Task credits__spend"
    Rails.logger.info "[#{name}] begin"

    websites = Website.in_statuses([Website::STATUS_ONLINE])

    Rails.logger.info "[#{name}] #{websites.count} to process"

    websites.each do |website|
      Rails.logger.info "[#{name}] processing #{website.site_name}"

      begin
        website.spend_hourly_credits!
      rescue StandardError => e
        Rails.logger.error "[#{name}] #{e.message}"

        if e.message.to_s.include?("No credits remaining")
          UserMailer.with(
            user: website.user,
            website: website
          ).stopped_due_no_credit.deliver_now
        end
      end

      website.credits_check_at = Time.zone.now
      website.save!
    end
  end
end
