class WebsiteBandwidthDailyStat < History
  belongs_to :website, foreign_key: :ref_id

  def self.last_stat_of(website)
    WebsiteBandwidthDailyStat.where(
      ref_id: website.id,
      created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day
    ).last
  end

  def self.last_days(website, days = 31)
    WebsiteBandwidthDailyStat
      .where(ref_id: website.id)
      .where(created_at: (days.days.ago)..Time.zone.now)
  end

  def self.sum_variable(stats, variable_name)
    return 0 unless stats

    stats.map { |s| s.obj[variable_name] || 0 }.sum
  end

  def self.log(website, data)
    last_stat = WebsiteBandwidthDailyStat.last_stat_of(website)

    if last_stat
      data.keys.each do |variable|
        if last_stat.obj[variable]&.is_a?(Numeric)
          last_stat.obj[variable] += data[variable]
        else
          last_stat.obj[variable] = data[variable]
        end
      end

      last_stat.save

      last_stat
    else
      WebsiteBandwidthDailyStat.create(
        ref_id: website.id,
        obj: data
      )
    end
  end
end
