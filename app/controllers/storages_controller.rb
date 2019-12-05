class StoragesController < InstancesController
  before_action :requires_cloud_plan, only: %i[increase decrease]

  api!
  def increase
    prepare_storage_change(sign: 1)
    change_storage(@gb_to_change)
  end

  api!
  def decrease
    prepare_storage_change(sign: -1)
    change_storage(- @gb_to_change)
  end

  protected

  def prepare_storage_change(opts = {})
    @gb_to_change = params['amount_gb'].to_i

    raise ApplicationRecord::ValidationError, 'amount_gb must be positive' if @gb_to_change <= 0

    signed_gb_to_change = opts[:sign] * @gb_to_change

    @website_event_obj = {
      title: 'Extra Storage modification',
      extra_storage_changed: "#{signed_gb_to_change} GBs",
      total_extra_storage: "#{@website_location.extra_storage + signed_gb_to_change} GBs"
    }
  end

  def change_storage(gb_to_change)
    @website_location.change_storage!(gb_to_change)
    @website_location.reload

    json(
      result: 'success',
      "Extra Storage (GB)": @website_location.extra_storage
    )
  end
end
