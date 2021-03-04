require "freshdesk"

Freshdesk.domain = ENV['FRESHDESK_DOMAIN']
Freshdesk.user_name_or_api_key = ENV['FRESHDESK_API_KEY']
Freshdesk.password_or_x = "X"

class SuperAdmin::SupportController < SuperAdmin::SuperAdminController
  def contact
    #message = params['message']&.gsub(/\n/, '<br>')
    #attributes = params.except('message')

    #params_freshdesk = {
    #  status: 2,
    #  priority: 1,
    #  description: "#{message}<br /><br /><hr />#{attributes.inspect}",
    #  subject: params['title'] || "opeNode Contact",
    #  cc_emails: [],
    #  email: params['email']
    #}
    #Freshdesk::Ticket.create_a_ticket(params: params_freshdesk)
    SupportMailer.with(
      attributes: params,
      email_to: ENV['DEFAULT_EMAIL']
    ).contact.deliver_now

    SupportMailer.with(
      attributes: params,
      email_to: "info@openode.io"
    ).contact.deliver_now

    json({})
  end
end
