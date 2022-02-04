
def post_instance(website, path_api, title)
  openode_api = Api::Openode.new(token: website.user.token)

  website.website_locations.each do |website_location|
    result_api_call = openode_api.execute(
      :post, path_api,
      params: { 'location_str_id' => website_location.location.str_id }
    )

    website.create_event(title: title,
                         api_result: result_api_call)
  end
end

def stop_instance(website, title)
  path_api = "/instances/#{website.site_name}/stop"

  post_instance(website, path_api, title)
end

def destroy_persistence_instance(website, title)
  path_api = "/instances/#{website.site_name}/destroy-storage"

  post_instance(website, path_api, title)
end

def destroy_addon_persistence(website)
  website.website_addons.select(&:online?).select(&:persistence?).each do |w_addon|
    path_api = "/instances/#{website.site_name}/addons/#{w_addon.id}/offline"

    post_instance(website, path_api, "deactivating addon persitence - lack of credit")
  end
end

namespace :credits do
  desc ''
  task online_spend: :environment do
    name = "Task credits__online__spend"
    credit_loop = CreditActionLoopOnlineSpend.create!
    Rails.logger.info "[#{name}] begin, loop = #{credit_loop}"

    websites = Website.select(:id).in_statuses([Website::STATUS_ONLINE]).pluck(:id)

    Rails.logger.info "[#{name}] #{websites.count} to process"

    websites.each do |website_id|
      website = Website.find(website_id)
      Rails.logger.info "[#{name}] processing #{website.site_name}"

      begin
        website.spend_online_hourly_credits!(1.0, credit_loop)
      rescue StandardError => e
        begin
          Rails.logger.error "[#{name}] #{e.message}"

          if e.message.to_s.include?("No credits remaining")
            # stop the instance:
            stop_instance(website, 'Stopping instance (lacking credits)')

            # notify the user:
            if website.alerting?(Website::ALERT_STOP_LACK_CREDITS)
              UserMailer.with(
                user: website.user,
                website: website
              ).stopped_due_no_credit.deliver_now
            end
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

      sleep 0.005 unless Rails.env.test?
    end
  end

  desc ''
  task verify_expired_open_source: :environment do
    name = "Task credits__verify_expired_open_source"
    Rails.logger.info "[#{name}] begin"

    websites = Website
               .in_statuses([Website::STATUS_ONLINE])
               .where(account_type: Website::OPEN_SOURCE_ACCOUNT_TYPE)

    Rails.logger.info "[#{name}] #{websites.count} to process"

    websites.each do |website|
      Rails.logger.info "[#{name}] processing #{website.site_name}"

      begin
        last_deployment = website.deployments.last

        if !last_deployment ||
           (Time.zone.today - last_deployment.created_at.to_date).to_i > 31

          Rails.logger.info "[#{name}] stopping expired os instance #{website.site_name}"

          stop_instance(website, 'Stopping instance, expired open source site')
        else
          Rails.logger.info "[#{name}] not stopping #{website.site_name}"
        end
      rescue StandardError => e
        Rails.logger.error e.to_s
      end
    end
  end
end
