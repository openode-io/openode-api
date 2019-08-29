class StoragesController < InstancesController

  before_action :prepare_storage_change

  def increase_storage
    @website_location.increase_storage!(@gb_to_change)
    @website_location.reload

    # TODO
		#logActivityStream(req.query.website, `Increase Storage`, {
		#	add: `${amountGB} GBs`,
		#	total_extra_storage: `${webLocation.extra_storage} GBs`
		#});

    json_res({
      result: "success",
      "Extra Storage (GB)": @website_location.extra_storage
    })
  end

  private

  def prepare_storage_change
    @gb_to_change = params["amount_gb"].to_i

    if @gb_to_change <= 0
      raise ApplicationRecord::ValidationError.new("amount_gb must be positive")
    end
  end

end
