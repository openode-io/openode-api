module Stats
  def prepare_daily_stats(klass, params)
    nb_days = (params['nb_days'] || 30).to_i
    entity_to_sum = params['attrib_to_sum']

    hash_entries = klass
                   .where('created_at > ?', nb_days.days.ago)
                   .group("DATE(created_at)")
                   .sum(entity_to_sum)

    hash_entries.map { |k, v| { date: k, value: v } }.sort_by { |e| e[:date] }
  end
end
