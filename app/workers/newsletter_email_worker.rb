class NewsletterEmailWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'default', retry: 1

  def perform(newsletter_id, email)
    newsletter = Newsletter.find(newsletter_id)

    NewsletterMailer.with(newsletter: newsletter, mail_to: email).trigger.deliver_now

    newsletter.reload
    newsletter.emails_sent << email
    newsletter.save
  end
end
