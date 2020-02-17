require 'test_helper'

class NewsletterTest < ActiveSupport::TestCase
  setup do
    reset_emails

    @custom_newsletter = Newsletter.create!(
      title: 'hi world.',
      content: 'hihihi.',
      recipients_type: 'custom',
      custom_recipients: ['what@gmaill.com', 'what2@gmaill.com']
    )

    @users_based_newsletter = Newsletter.create!(
      title: 'hi world.',
      content: 'hihihi.',
      recipients_type: 'newsletter'
    )

    @emails_in_newsletter = ["myadmin2@thisisit.com", "myadmin@thisisit.com"]
  end

  test "emails sent should be empty on init" do
    assert_equal @custom_newsletter.emails_sent, []
  end

  test "emails with custom" do
    assert_equal @custom_newsletter.emails, @custom_newsletter.custom_recipients
  end

  test "emails to send with custom - nothing sent" do
    assert_equal @custom_newsletter.emails_to_send, @custom_newsletter.custom_recipients
  end

  test "emails to send with custom - one sent" do
    first_mail = @custom_newsletter.custom_recipients.first
    @custom_newsletter.emails_sent << first_mail
    @custom_newsletter.save!
    assert_equal @custom_newsletter.emails_to_send,
                 @custom_newsletter.custom_recipients - [first_mail]
  end

  test "emails with newsletter" do
    assert_equal @users_based_newsletter.emails, @emails_in_newsletter
  end

  test "emails to send with newsletter - nothing sent" do
    assert_equal @users_based_newsletter.emails_to_send, @emails_in_newsletter
  end

  test "emails to send with newsletter - one sent" do
    first_mail = @emails_in_newsletter.first
    @users_based_newsletter.emails_sent << first_mail
    @users_based_newsletter.save!
    assert_equal @users_based_newsletter.emails_to_send,
                 @emails_in_newsletter - [first_mail]
  end

  test "deliver newsletter - custom" do
    emails_to_send = @custom_newsletter.emails_to_send
    emails_sent = @custom_newsletter.deliver!

    assert_equal emails_to_send, emails_sent

    invoke_all_jobs

    assert_equal ActionMailer::Base.deliveries.count, emails_to_send.count

    ActionMailer::Base.deliveries.each do |delivered_mail|
      assert_equal delivered_mail.subject, @custom_newsletter.title
      assert_includes delivered_mail.body.raw_source, @custom_newsletter.content

      assert_includes emails_to_send, delivered_mail.to[0]
    end
  end
end
