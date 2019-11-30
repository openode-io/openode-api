
namespace :db_stats do
  desc ''
  task log_nb_sites_up: :environment do
    name = "Task db_stats:log_nb_sites_up"
    Rails.logger.info "[#{name}] begin"

    nb_online = Website.where(status: 'online').count

    SystemStat.create!(obj: { nb_online: nb_online })
    Rails.logger.info "[#{name}] nb online = #{nb_online}"
  end
end
