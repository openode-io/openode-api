class UserMailer < ApplicationMailer
  def registration
    @user = params[:user]
    @activation_link = "https://www.#{CloudProvider::Manager.base_hostname}/" \
                       "activate/#{@user.id}/#{@user.activation_hash}"
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

  def stopped_due_no_credit
    @user = params[:user]
    @website = params[:website]
    mail_to = @user.email

    mail(to: mail_to, subject: "#{@website.site_name}@opeNode stopped")
  end

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
end
