require 'json'

class SupportMailer < ApplicationMailer
  def contact
    @message = params[:attributes]['message']&.gsub(/\n/, '<br>')
    attributes = params[:attributes].except('message')
    @content = JSON.pretty_generate(attributes)

    mail_to = params[:email_to] || ENV['DEFAULT_EMAIL']

    mail(to: mail_to, subject: params[:title] || "opeNode Contact")
  end
end
