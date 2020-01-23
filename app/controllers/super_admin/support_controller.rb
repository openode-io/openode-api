class SuperAdmin::SupportController < SuperAdmin::SuperAdminController

  def contact
    SupportMailer.with(
      attributes: { asdf: 1234 },
      email_to: ENV['DEFAULT_EMAIL']
    ).contact.deliver_now

    json({})
  end

end
