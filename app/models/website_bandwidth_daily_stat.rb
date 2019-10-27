class WebsiteBandwidthDailyStat < History
  belongs_to :website, foreign_key: :ref_id

  def self.log(website, data)
    last_stat = WebsiteBandwidthDailyStat.where(
      ref_id: website.id,
      created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day
    ).last

    if last_stat
      data.keys.each do |variable|
        if last_stat.obj[variable]
          last_stat.obj[variable] += data[variable]
        else
          last_stat.obj[variable] = data[variable]
        end
      end

      last_stat.save
    else
      WebsiteBandwidthDailyStat.create(
        ref_id: website.id,
        obj: data
      )
    end
  end
end
