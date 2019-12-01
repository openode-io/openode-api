
namespace :background_notification do
  desc ''
  task after_one_day_registration: :environment do
    name = "Task background_notification:after_one_day_registration"
    Rails.logger.info "[#{name}] begin"

    users = User.where('created_at < ? AND day_one_mail_at IS ?', 1.day.ago, nil).limit(500)

    users.each do |user|
      Rails.logger.info "[#{name}] notifying #{user.email}"
      user.day_one_mail_at = Time.zone.now
      user.save

      UserMailer.with(user: user).one_day_notification.deliver_now
    end
  end
end
