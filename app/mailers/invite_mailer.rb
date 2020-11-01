class InviteMailer < ApplicationMailer
  def send_invite
    @user = params[:user]

    mail_to = params[:email_to]

    mail(to: mail_to, subject: "Invitation to join opeNode.io")
  end
end
