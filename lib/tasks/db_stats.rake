
namespace :db_stats do
  desc ''
  task log_system_stat: :environment do
    name = "Task db_stats__log_system_stat"
    Rails.logger.info "[#{name}] begin"

    nb_online = Website.where(status: 'online').count
    nb_active_users = User.where(created_at: 31.days.ago..Time.current).count

    SystemStat.create!(obj: {
                         nb_online: nb_online, nb_active_users: nb_active_users
                       })
    Rails.logger.info "[#{name}] nb online = #{nb_online}, " \
                      "nb_active_users = #{nb_active_users}"
  end
end
