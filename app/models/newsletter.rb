class Newsletter < ApplicationRecord
  before_create :init

  serialize :custom_recipients, JSON
  serialize :emails_sent, JSON

  validates :title, presence: true
  validates :recipients_type, presence: true
  validates :recipients_type, inclusion: { in: %w[custom newsletter] }

  def init
    self.emails_sent = []
  end

  def emails
    send("emails_#{recipients_type}")
  end

  def emails_custom
    custom_recipients || []
  end

  def emails_newsletter
    User.select(:email).where(newsletter: [1, true]).pluck(:email)
  end

  def emails_to_send
    emails - emails_sent
  end

  def deliver!
    emails_to_deliver = []

    emails_to_send.each do |email|
      Rails.logger.info("Newsletter #{title} - enqueing mail #{email}")

      NewsletterEmailWorker.perform_async(id, email)

      emails_to_deliver << email
    end

    emails_to_deliver
  end
end
