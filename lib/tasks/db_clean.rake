
namespace :db_clean do
  def clean_table(args)
    args[:Model].where('created_at < ?', args[:days_retention].days.ago).each do |instance|
      Rails.logger.info "[#{args[:name]}] removing entity #{instance.id}"

      GlobalStat.increase!(args[:stat_name], 1)

      instance.destroy
    end
  end

  def hard_clean_table(args)
    result = args[:Model].where('created_at < ?', args[:days_retention].days.ago)
    Rails.logger.info "[#{args[:name]}] hard clean table #{args[:stat_name]} count=#{result.count}"
    result.destroy_all
  end

  desc ''
  task old_deployments: :environment do
    name = "Task db_clean__old_deployments"
    Rails.logger.info "[#{name}] begin"
    days_retention = 31

    deployments_to_consider =
      Deployment.type_dep.where('created_at < ?', days_retention.days.ago)

    deployments_to_consider.each do |deployment|
      Rails.logger.info "[#{name}] removing entity #{deployment.id}"

      if deployment.website
        last_successful_deployment = deployment.website.deployments.success.last

        days_dep_created = (Time.zone.now - deployment.created_at.in_time_zone) / (60 * 60 * 24)
        is_too_old_and_not_online = days_dep_created >= 60 &&
                                    deployment.website.status != Website::STATUS_ONLINE

        if (last_successful_deployment == deployment ||
           deployment.id == last_successful_deployment&.image_execution_id) &&
           !is_too_old_and_not_online
          Rails.logger.info "[#{name}] keeping latest #{deployment.id}"

          next
        end
      end

      Rails.logger.info "[#{name}] destroying deployment #{deployment.id}"

      GlobalStat.increase!("nb_archived_deployments", 1)
      deployment.destroy
    rescue StandardError => e
      Rails.logger.error "[#{name}] error = #{e}"
    end
  end

  desc ''
  task old_task_executions: :environment do
    name = "Task db_clean__old_task_executions"
    Rails.logger.info "[#{name}] begin"
    days_retention = 1

    hard_clean_table(
      Model: Execution.not_types(['Deployment']),
      days_retention: days_retention,
      name: name,
      stat_name: "nb_archived_task_executions"
    )
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

  desc ''
  task old_credit_actions: :environment do
    name = "Task db_clean__old_credit_actions"
    Rails.logger.info "[#{name}] begin"

    days_retention = 45

    clean_table(
      Model: CreditAction,
      days_retention: days_retention,
      name: name,
      stat_name: "nb_archived_credit_actions"
    )

    clean_table(
      Model: CreditActionLoop,
      days_retention: days_retention,
      name: name,
      stat_name: "nb_archived_credit_action_loops"
    )
  end
end
