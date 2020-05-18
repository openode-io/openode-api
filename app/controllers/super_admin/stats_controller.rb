class SuperAdmin::StatsController < SuperAdmin::SuperAdminController
  def spendings
    nb_days = (params['nb_days'] || 30).to_i

    hash_entries = CreditAction
                   .where('created_at > ?', nb_days.days.ago)
                   .group("DATE(created_at)")
                   .sum(:credits_spent)

    json(hash_entries.map { |k, v| { date: k, value: v } }.sort_by { |e| e[:date] })
  end

  def nb_online
    nb_days = (params['nb_days'] || 30).to_i

    stats = SystemStat
            .where('created_at > ?', nb_days.days.ago)

    json(
      stats
      .map { |s| { date: s.created_at.to_date, value: s.obj.dig('nb_online') } }
      .sort_by do |e|
        e[:created_at]
      end
    )
  end
end
