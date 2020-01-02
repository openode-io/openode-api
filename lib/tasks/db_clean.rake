
namespace :db_clean do
  def clean_table(args)
    args[:Model].where('created_at < ?', args[:days_retention].days.ago).each do |instance|
      Rails.logger.info "[#{args[:name]}] removing entity #{instance.id}"

      GlobalStat.increase!(args[:stat_name], 1)

      instance.destroy
    end
  end

  desc ''
  task old_executions: :environment do
    name = "Task db_clean__old_executions"
    Rails.logger.info "[#{name}] begin"
    days_retention = 31

    objects = [
      {
        model: Deployment,
        stat_name: "nb_archived_deployments"
      },
      {
        model: Execution,
        stat_name: "nb_archived_executions"
      }
    ]

    objects.each do |object_to_archived|
      clean_table(
        Model: object_to_archived[:model],
        days_retention: days_retention,
        name: name,
        stat_name: object_to_archived[:stat_name]
      )
    end
  end

  desc ''
  task old_histories: :environment do
    name = "Task db_clean__old_histories"
    Rails.logger.info "[#{name}] begin"

    days_retention = 62

    clean_table(
      Model: History,
      days_retention: days_retention,
      name: name,
      stat_name: "nb_archived_histories"
    )
  end
end
