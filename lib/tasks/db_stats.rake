
namespace :db_stats do
  desc ''
  task log_nb_sites_up: :environment do
    nb_online = Website.where(status: 'online').count

    SystemStat.create!(obj: { nb_online: nb_online })
  end
end
