# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def registration
    @user = params[:user]
    @activation_link = "https://www.#{CloudProvider::Manager.instance.base_hostname}/" \
                       "activate/#{@user.id}/#{@user.activation_hash}"
    mail_to = @user.email

    mail(to: mail_to, subject: 'Welcome to opeNode!')
  end
end
