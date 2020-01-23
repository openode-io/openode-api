require 'json'

class SupportMailer < ApplicationMailer
  def contact
    @message = params[:attributes]['message']
    attributes = params[:attributes].except('message')
    @content = JSON.pretty_generate(attributes)
    
    mail_to = params[:email_to]

    mail(to: mail_to, subject: "opeNode Contact")
  end
end
