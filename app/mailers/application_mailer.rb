class ApplicationMailer < ActionMailer::Base
  default from: CloudProvider::Manager.instance.application["main_email"]
  layout 'mailer'
end
