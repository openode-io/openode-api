
namespace :db_clean do
  desc ''
  task old_executions: :environment do
    name = "Task db_clean:old_executions"
    Rails.logger.info "[#{name}] begin"

    days_retention = 31

    Execution.where('created_at < ?', days_retention.days.ago).each do |execution|
      Rails.logger.info "[#{name}] removing execution #{execution.id}"

      GlobalStat.increase!("nb_archived_executions", 1)

      execution.destroy
    end
  end
end
