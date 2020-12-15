
namespace :mailjet do
  desc ''
  task add_recent: :environment do
    name = "Task mailjet__add_recent"
    Rails.logger.info "[#{name}] begin"

    users = User.where(created_at: 2.days.ago..Time.zone.now, newsletter: 1)

    users.each do |user|
      Rails.logger.info "[#{name}] adding user #{user.email}"
      Api::Mailjet.new.add_contact(user.email)
    rescue StandardError => e
      Rails.logger.error e
    end
  end
end
