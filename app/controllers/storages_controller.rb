class StoragesController < InstancesController

  before_action :prepare_storage_change
  after_action :record_website_event

  def increase_storage
    @website_location.increase_storage!(@gb_to_change)
    @website_location.reload

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

  def record_website_event
    WebsiteEvent.create({
      ref_id: @website.id,
      obj: {
        title: "Extra Storage modification",
        extra_storage_changed: "#{@gb_to_change} GBs",
        total_extra_storage: "#{@website_location.extra_storage} GBs"
      }
    })
  end

end
