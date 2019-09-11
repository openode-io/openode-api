class StoragesController < InstancesController

  before_action :requires_cloud_plan, only: [:increase, :decrease]

  def increase
    self.prepare_storage_change({ sign: 1 })
    self.change_storage(@gb_to_change)
  end

  def decrease
    self.prepare_storage_change({ sign: -1})
    self.change_storage(- @gb_to_change)
  end

  protected

  def prepare_storage_change(opts = {})
    @gb_to_change = params["amount_gb"].to_i

    if @gb_to_change <= 0
      raise ApplicationRecord::ValidationError.new("amount_gb must be positive")
    end

    signed_gb_to_change = opts[:sign] * @gb_to_change

    @website_event_obj = {
      title: "Extra Storage modification",
      extra_storage_changed: "#{signed_gb_to_change} GBs",
      total_extra_storage: "#{@website_location.extra_storage + signed_gb_to_change} GBs"
    }
  end

  def change_storage(gb_to_change)
    @website_location.change_storage!(gb_to_change)
    @website_location.reload

    json_res({
      result: "success",
      "Extra Storage (GB)": @website_location.extra_storage
    })
  end
end
