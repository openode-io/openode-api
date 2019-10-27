class WebsiteBandwidthDailyStat < History
  belongs_to :website, foreign_key: :ref_id

  def self.log(website, data)
    last_stat = WebsiteBandwidthDailyStat.where(
      ref_id: website.id,
      created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day
    ).last

    # puts "last stat = #{last_stat}"
    unless last_stat
      WebsiteBandwidthDailyStat.create(
        ref_id: website.id,
        obj: data
      )
    end
  end
end
