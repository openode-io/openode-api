class WebsiteEventsChannel < ApplicationCable::Channel
  def self.id_channel(website)
    "website:#{website.id}"
  end

  def self.full_id_channel(website)
    "website_events:#{WebsiteEventsChannel.id_channel(website)}"
  end

  def subscribed
    website_id = params['website_id']

    website = Website.find_by! id: website_id

    reject unless website.accessible_by?(current_user)

    Rails.logger.info('WebsiteEventsChannel - subscribed channel for ' \
      "website id #{website_id}...")

    stream_from WebsiteEventsChannel.full_id_channel(website)
  end

  def unsubscribed; end
end
