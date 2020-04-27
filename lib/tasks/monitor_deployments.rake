
namespace :monitor_deployments do
  desc ''
  task pod_status: :environment do
    name = "Task monitor_deployments__pod_status"
    Rails.logger.info "[#{name}] begin"

    websites = Website
               .in_statuses([Website::STATUS_ONLINE])
               .where(type: Website::TYPE_KUBERNETES)

    websites.each do |website|
      Rails.logger.info "[#{name}] current website #{website.site_name}"
      wl = website.website_locations.first

      exec_method = wl.prepare_runner.get_execution_method

      result = exec_method.get_pods_json(website: website, website_location: wl)

      status = result&.dig('items')&.first&.dig('status')

      WebsiteStatus.log(website, status)
    rescue StandardError => e
      Ex::Logger.error(e, "[#{name}] failed with website #{website.site_name}")
    end
  end

  def bytes_consumed(website)
    stats = WebsiteBandwidthDailyStat.last_days(website)

    WebsiteBandwidthDailyStat.sum_variable(stats, 'rcv_bytes') +
      WebsiteBandwidthDailyStat.sum_variable(stats, 'tx_bytes')
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

      result = exec_method.ex_stdout("custom_cmd",
                                     website_location: wl,
                                     cmd: "cat /proc/net/dev")

      new_network_metrics = Io::Net.parse_proc_net_dev(result, exclude_interfaces: ['lo'])

      previous_net_metrics =
        website.website_bandwidth_daily_stats.last&.obj&.dig('previous_network_metrics')

      network_metrics = Io::Net.diff(new_network_metrics, previous_net_metrics)

      already_bytes_consumed = bytes_consumed(website)

      WebsiteBandwidthDailyStat.log(website, {
                                      'previous_network_metrics' => new_network_metrics,
                                      'rcv_bytes' => network_metrics['rcv_bytes'],
                                      'tx_bytes' => network_metrics['tx_bytes']
                                    })

      Rails.logger.info "[#{name}] limit = #{website.bandwidth_limit_in_bytes}, " \
                        "bytes consumed = #{already_bytes_consumed}"

      if Website.exceeds_bandwidth_limit?(website, already_bytes_consumed)
        new_bytes = network_metrics['rcv_bytes'].to_f + network_metrics['tx_bytes'].to_f

        Rails.logger.info "[#{name}] exceeding bandwidth limit " \
                          "for website #{website.site_name}, new bytes = #{new_bytes}"

        # TODO: put back test also
        # website.spend_exceeding_traffic!(new_bytes)
      end
    rescue StandardError => e
      Ex::Logger.error(e, "[#{name}] failed with website #{website.site_name} - #{e}")
    end
  end
end
