class InstanceStatController < InstancesController
  api!
  def index
    last_bws = @website.website_bandwidth_daily_stats.where('created_at > ?', 24.hours.ago)
    last_util_logs =
      @website.website_utilization_logs.where('created_at > ?', 24.hours.ago)

    json(
      mem: extract_specific_stats(last_util_logs, 'mem_d'),
      disk: extract_specific_stats(last_util_logs, 'disk_usage'),
      cpu: extract_specific_stats(last_util_logs, 'cpu_d'),
      bandwidth_inbound: extract_specific_stats(last_bws, 'inbound'),
      bandwidth_outbound: extract_specific_stats(last_bws, 'outbound')
    )
  end

  protected

  def extract_specific_stats(rows, metric_name)
    rows.map do |row|
      {
        'value' => row.obj[metric_name],
        'date' => row.created_at.iso8601
      }
    end
  end
end
