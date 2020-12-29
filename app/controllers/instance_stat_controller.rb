class InstanceStatController < InstancesController
  api :GET, 'instances/:id/stats'
  description 'Returns the instance statistics.'
  returns code: 200, desc: "" do
    property :top, Array, desc: "Array following this format: [{ service, cpu_raw, memory_raw }]"
  end
  def index
    result_top_cmd = @runner.execute([
                                       {
                                         cmd_name: 'top_cmd', options: {
                                           website: @website.clone,
                                           website_location: @website_location
                                         }
                                       }
                                     ]).first.dig(:result, :stdout)

    result_top = @runner.execution_method.top(result_top_cmd)

    json(top: result_top)
  end

  api!
  def spendings
    nb_days = (params['nb_days'] || 30).to_i

    hash_entries = CreditAction
                   .where(website_id: @website.id)
                   .where('created_at > ?', nb_days.days.ago)
                   .group("DATE(created_at)")
                   .sum(:credits_spent)

    json(hash_entries.map { |k, v| { date: k, value: v } }.sort_by { |e| e[:date] })
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
