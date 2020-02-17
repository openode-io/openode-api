class NewsletterMailer < ApplicationMailer
  def trigger
    assert params[:newsletter]
    assert params[:mail_to]

    @newsletter = params[:newsletter]
    mail_to = params[:mail_to]

    @content = @newsletter.content.html_safe

    mail(to: mail_to, subject: @newsletter.title)
  end
end
