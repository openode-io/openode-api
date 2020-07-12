class Deployment < Execution
  MAX_RUN_TIME = 20.minutes
  MAX_CONCURRENT_BUILDS_PER_USER = 2
  NB_JOB_QUEUES = 5

  scope :active, lambda {
    where("created_at >= ?", MAX_RUN_TIME.ago)
  }

  scope :type_dep, lambda {
    where(type: 'Deployment')
  }

  def self.nb_archived_deployments
    stat = GlobalStat.first

    return 0 unless stat

    stat.obj['nb_archived_deployments'] || 0
  end

  def self.total_nb
    Deployment.type_dep.count + # active ones
      Deployment.nb_archived_deployments # + archived
  end

  def image_execution_id
    tag_separator = DeploymentMethod::Util::InstanceImageManager::TAG_NAME_SEPARATOR
    last_part = obj&.dig('image_name_tag')&.split(tag_separator)&.last

    last_part&.to_i
  end

  def humanize_events
    return "" unless events

    events
      .map { |e| e["update"] || "" }
      .join("\n\n")
  end
end
