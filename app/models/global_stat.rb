class GlobalStat < GlobalStorage
  def self.increase!(variable, value)
    instance = GlobalStat.first_or_create
    instance.obj ||= {}

    instance.obj[variable] ||= 0
    instance.obj[variable] += value

    instance.save

    instance
  end
end
