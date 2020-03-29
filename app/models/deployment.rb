class Deployment < Execution
  def self.nb_archived_deployments
    stat = GlobalStat.first

    return 0 unless stat

    stat.obj['nb_archived_deployments'] || 0
  end

  def self.total_nb
    Deployment.count + # active ones
      Deployment.nb_archived_deployments # + archived
  end

  def humanize_events
    return "" unless events

    events
      .map { |e| e["update"] || "" }
      .join("\n\n")
  end
end
