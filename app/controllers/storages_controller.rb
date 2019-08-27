class StoragesController < InstancesController

  before_action :prepare_storage_change

  def increase_storage
    json_res(@website)
  end

  private

  def prepare_storage_change
    @gb_to_increase = params["amount_gb"].to_i

    if @gb_to_increase <= 0
      raise ApplicationRecord::ValidationError.new("amount_gb must be positive")
    end
  end

end
