
module WithPlan
  MAX_RAM_PLAN_WITHOUT_PAID_ORDER = 100

  def self.plan_of(acc_type)
    plans = CloudProvider::Manager.instance.available_plans

    plans.find { |p| [p[:id], p[:internal_id]].include?(acc_type) }
  end

  def self.find_min_plan(minimum_memory)
    plans = CloudProvider::Manager.instance.available_plans

    plans.find do |p|
      p[:ram] >= minimum_memory &&
        p[:internal_id] != Website::OPEN_SOURCE_ACCOUNT_TYPE
    end
  end

  def plan
    WithPlan.plan_of(account_type)
  end

  def memory
    plan[:ram].to_i # must not have decimals
  end

  def validate_account_type
    found_plan = Website.plan_of(account_type)
    return errors.add(:account_type, "Invalid plan #{account_type}") unless found_plan

    if found_plan.dig(:ram) &&
       found_plan[:ram] > MAX_RAM_PLAN_WITHOUT_PAID_ORDER && !user.orders?
      errors.add(:account_type,
                 "Maximum available plan without a paid order is " \
                 "#{MAX_RAM_PLAN_WITHOUT_PAID_ORDER} MB RAM.")
    end
  end
end
