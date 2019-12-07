
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
          # stop the instance:
          openode_api = Api::Openode.new(token: website.user.token)
          # '/instances/testsite/stop?location_str_id=canada'
          path_api = "/instances/#{website.site_name}/stop"

          website.website_locations.each do |website_location|
            result_api_call = openode_api.execute(
              :post, path_api,
              params: { 'location_str_id' => website_location.location.str_id }
            )

            website.create_event(title: 'Stopping instance (lacking credits)',
                                 api_result: result_api_call)
          end

          # notify the user:

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
