require 'mailjet'

module Api
  class Mailjet
    def initialize
      ::Mailjet.configure do |config|
        config.api_key = ENV['MAILJET_API_KEY']
        config.secret_key = ENV['MAILJET_SECRET_KEY']
        config.api_version = "v3"
      end
    end

    def add_contact(email)
      ::Mailjet::Contact.create(email: email) rescue nil
      ::Mailjet::Listrecipient.create(
        is_unsubscribed: "false",
        contact_alt: email,
        list_id: ENV["MAILJET_CONTACT_LIST_ID"]
      )
    end
  end
end
