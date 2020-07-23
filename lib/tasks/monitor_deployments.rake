
namespace :monitor_deployments do
  def bytes_consumed(website)
    stats = WebsiteBandwidthDailyStat.last_days(website)

    WebsiteBandwidthDailyStat.sum_variable(stats, 'rcv_bytes') +
      WebsiteBandwidthDailyStat.sum_variable(stats, 'tx_bytes')
  end

  def record_bandwidth(website, result, opts = {})
    raw_result = result.dig(:result)
    pod_name = result.dig(:name)

    new_network_metrics = Io::Net.parse_proc_net_dev(raw_result, exclude_interfaces: ['lo'])

    latest_daily_stat = website.website_bandwidth_daily_stats.last
    previous_net_metrics_obj = latest_daily_stat&.obj&.dig('previous_network_metrics')
    previous_net_metrics = previous_net_metrics_obj&.dig(pod_name)

    network_metrics = Io::Net.diff(new_network_metrics, previous_net_metrics)

    already_bytes_consumed = bytes_consumed(website)

    previous_net_metrics_obj ||= {}
    previous_net_metrics_obj[pod_name] = new_network_metrics
    WebsiteBandwidthDailyStat.log(website,
                                  'previous_network_metrics' => previous_net_metrics_obj,
                                  'rcv_bytes' => network_metrics['rcv_bytes'],
                                  'tx_bytes' => network_metrics['tx_bytes'])

    Rails.logger.info "[#{opts[:task_name]}] limit = #{website.bandwidth_limit_in_bytes}, " \
                      "new_network_metrics = #{network_metrics} " \
                      "bytes already consumed = #{already_bytes_consumed}"

    if Website.exceeds_bandwidth_limit?(website, already_bytes_consumed)
      new_bytes = network_metrics['rcv_bytes'].to_f + network_metrics['tx_bytes'].to_f

      Rails.logger.info "[#{opts[:task_name]}] exceeding bandwidth limit " \
                        "for website #{website.site_name}, new bytes = #{new_bytes}"

      website.spend_exceeding_traffic!(new_bytes)
    end
  end

  task bandwidth: :environment do
    name = "Task monitor_deployments__bandwidth"
    Rails.logger.info "[#{name}] begin"

    websites = Website
               .in_statuses([Website::STATUS_ONLINE])
               .where(type: Website::TYPE_KUBERNETES)

    websites.each do |website|
      Rails.logger.info "[#{name}] current website #{website.site_name}"
      wl = website.website_locations.first

      exec_method = wl.prepare_runner.get_execution_method

      results = exec_method.ex_on_all_pods_stdout("custom_cmd",
                                                  website: website,
                                                  website_location: wl,
                                                  cmd: "cat /proc/net/dev")

      results.each do |result|
        record_bandwidth(website, result, task_name: name)
      end
    rescue StandardError => e
      Ex::Logger.error(e, "[#{name}] failed with website #{website.site_name} - #{e}")
    ensure
      exec_method&.destroy_execution
    end
  end
end
