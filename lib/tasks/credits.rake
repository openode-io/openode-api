
namespace :credits do
  desc ''
  task online_spend: :environment do
    name = "Task credits__online__spend"
    Rails.logger.info "[#{name}] begin"

    websites = Website.in_statuses([Website::STATUS_ONLINE])

    Rails.logger.info "[#{name}] #{websites.count} to process"

    websites.each do |website|
      Rails.logger.info "[#{name}] processing #{website.site_name}"

      begin
        website.spend_online_hourly_credits!
      rescue StandardError => e
        begin
          Rails.logger.error "[#{name}] #{e.message}"

          if e.message.to_s.include?("No credits remaining")
            # stop the instance:
            openode_api = Api::Openode.new(token: website.user.token)
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
        rescue StandardError => e
          Rails.logger.error e.to_s
        end
      end

      begin
        website.credits_check_at = Time.zone.now
        website.save!
      rescue StandardError => e
        msg = "[#{name}] issue updating credits check at of #{website.site_name}: #{e}"
        Rails.logger.error msg
      end
    end
  end

  desc ''
  task persistence_spend: :environment do
    name = "Task credits__persistence__spend"
    Rails.logger.info "[#{name}] begin"

    websites = Website.having_extra_storage

    Rails.logger.info "[#{name}] #{websites.count} to process"

    websites.each do |website|
      Rails.logger.info "[#{name}] processing #{website.site_name}"

      begin
        website.spend_persistence_hourly_credits!
      rescue StandardError => e
        Rails.logger.error "[#{name}] #{e.message}"

        if e.message.to_s.include?("No credits remaining")
          # destroy the persitence:
          openode_api = Api::Openode.new(token: website.user.token)
          path_api = "/instances/#{website.site_name}/destroy-storage"

          website.website_locations.each do |website_location|
            result_api_call = openode_api.execute(
              :post, path_api,
              params: { 'location_str_id' => website_location.location.str_id }
            )

            website.create_event(title: 'Destroying persistence (lacking credits)',
                                 api_result: result_api_call)
          end

          # notify the user:

          UserMailer.with(
            user: website.user,
            website: website
          ).stopped_due_no_credit_persistence.deliver_now
        end
      end
    end
  end
end
