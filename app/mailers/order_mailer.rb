class OrderMailer < ApplicationMailer
  def confirmation
    @order = params[:order]
    @comment = params[:comment] || ''

    mail_to = params[:email_to] || @order.user.email

    mail(to: mail_to, subject: "opeNode Order ##{@order.id} Confirmation")
  end
end
