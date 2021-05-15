namespace :suspension do
  desc ''
  task shutdown_suspended_user_websites: :environment do
    name = "Task suspension__shutdown_suspended_user_websites"
    Rails.logger.info "[#{name}] begin"

    suspended_user_ids = User.where(suspended: 1).pluck(:id)

    Website.where(user_id: suspended_user_ids).update_all(status: Website::STATUS_OFFLINE)
  end
end
