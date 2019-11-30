require 'vultr'

namespace :mailgun do
  desc 'Verify failed events, unsubscribe newsletter for emails with failed'
  task check_failed_events: :environment do
    mg_client = Mailgun::Client.new(ENV['MAILGUN_API_KEY'])
    mg_events = Mailgun::Events.new(mg_client, ENV['MAILGUN_DOMAIN'])

    result = mg_events.get('limit' => 300, 'event' => 'failed')

    failed_event_items = result.to_h['items']

    failed_event_items.each do |item|
      user = User.find_by email: item['recipient']
      next unless user
      next unless user.newsletter?

      Rails.logger.info "Deactivating newsletter for using #{user.email}"

      user.newsletter = false
      user.save

    rescue StandardError => e
      Ex::Logger.error(e, "Issue checking failed event for #{item.inspect}")
    end
  end
end
