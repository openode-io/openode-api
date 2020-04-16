class InstanceStatController < InstancesController
  api!
  def index
    last_bws = @website.website_bandwidth_daily_stats.where('created_at > ?', 24.hours.ago)

    json(
      bandwidth_inbound: extract_specific_stats(last_bws, 'inbound'),
      bandwidth_outbound: extract_specific_stats(last_bws, 'outbound')
    )
  end

  api!
  def spendings
    nb_days = (params['nb_days'] || 30).to_i

    hash_entries = CreditAction
                   .where(website_id: @website.id)
                   .where('created_at > ?', nb_days.days.ago)
                   .group("DATE(created_at)")
                   .sum(:credits_spent)

    json(hash_entries.map { |k, v| { date: k, value: v } })
  end

  api!
  def network
    nb_days = (params['nb_days'] || 30).to_i

    entries = WebsiteBandwidthDailyStat
              .where(ref_id: @website.id)
              .where('created_at > ?', nb_days.days.ago)

    json(entries)
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
