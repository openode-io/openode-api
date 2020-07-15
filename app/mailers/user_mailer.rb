class UserMailer < ApplicationMailer
  def registration
    @user = params[:user]
    @activation_link = activation_link(@user)
    mail_to = @user.email

    mail(to: mail_to, subject: 'Welcome to opeNode!')
  end

  def registration_collaborator
    @user = params[:user]
    @password = params[:password]
    @activation_link = activation_link(@user)
    mail_to = @user.email

    mail(to: mail_to, subject: 'Welcome to opeNode!')
  end

  def one_day_notification
    @user = params[:user]
    mail_to = @user.email

    mail(to: mail_to, subject: 'New opeNode User Support')
  end

  def low_credit
    @user = params[:user]
    mail_to = @user.email

    mail(to: mail_to, subject: 'Your opeNode account has low credit')
  end

  def forgot_password
    @user = params[:user]
    mail_to = @user.email

    mail(to: mail_to, subject: 'opeNode Password Reset')
  end

  def stopped_due_no_credit
    @user = params[:user]
    @website = params[:website]
    mail_to = @user.email

    mail(to: mail_to, subject: "#{@website.site_name}@opeNode stopped")
  end

  def stopped_due_reason
    @user = params[:user]
    @website = params[:website]
    @reason = params[:reason]
    mail_to = @user.email

    mail(to: mail_to, subject: "#{@website.site_name}@opeNode stopped")
  end

  def response_open_source_request
    @user = params[:user]
    @website = params[:website]
    mail_to = @user.email

    mail(to: mail_to, subject: "opeNode open source request updated")
  end

  def stopped_due_no_credit_persistence
    @user = params[:user]
    @website = params[:website]
    mail_to = @user.email

    mail(to: mail_to, subject: "#{@website.site_name}@opeNode persistence removed")
  end

  # TODO: deprecate
  # ip, sitename, default_password, pubkey, privkey, mail_to
  def private_cloud_ready
    @ip = params[:ip]
    @sitename = params[:sitename]
    @default_password = params[:default_password]
    @pubkey = params[:pubkey]

    attachments['id_rsa'] = params[:privkey]

    subject = "Your private cloud server is ready - #{CloudProvider::Manager.base_hostname}"
    mail(to: params[:mail_to], subject: subject)
  end

  protected

  def activation_link(user)
    "https://www.#{CloudProvider::Manager.base_hostname}/" \
                       "activate/#{user.id}/#{user.activation_hash}"
  end
end
