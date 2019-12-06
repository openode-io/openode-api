
namespace :background_notification do
  desc ''
  task after_one_day_registration: :environment do
    name = "Task background_notification__after_one_day_registration"
    Rails.logger.info "[#{name}] begin"

    users = User.where('created_at < ? AND day_one_mail_at IS ?', 1.day.ago, nil).limit(500)

    users.each do |user|
      Rails.logger.info "[#{name}] notifying #{user.email}"
      user.day_one_mail_at = Time.zone.now
      user.save

      UserMailer.with(user: user).one_day_notification.deliver_now
    end
  end

  desc ''
  task low_credit: :environment do
    name = "Task background_notification__low_credit"
    Rails.logger.info "[#{name}] begin"

    users = User
            .lacking_credits
            .not_notified_low_credit
            .having_websites_in_statuses([Website::STATUS_ONLINE])

    users.each do |user|
      Rails.logger.info "[#{name}] notifying user #{user.email}"

      user.notified_low_credit = true
      user.save!

      UserMailer.with(user: user).low_credit.deliver_now
    rescue StandardError => e
      Ex::Logger.error(e, "issue processing low credit task")
    end

    users_change_notified_low =
      User.where('credits > nb_credits_threshold_notification AND notified_low_credit = 1')

    users_change_notified_low.each do |user|
      Rails.logger.info "[#{name}] switching notified_low_credit, #{user.email}"
      user.notified_low_credit = 0
      user.save
    end
  end
end
