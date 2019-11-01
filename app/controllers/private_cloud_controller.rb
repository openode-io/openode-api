class PrivateCloudController < InstancesController
  before_action only: [:allocate, :apply] do
    requires_private_cloud_plan
  end

  before_action only: [:apply] do
    requires_active_private_cloud_allocation
  end

  def allocate
    if @website.data && @website.data['privateCloudInfo']
      return json(success: 'Instance already allocated')
    end

    raise ApplicationRecord::ValidationError, 'No credit available' unless @website.user.credits?

    cloud_manager = CloudProvider::Manager.instance
    cloud_provider = cloud_manager.first_of_internal_type(CloudProvider::Vultr::TYPE)

    cloud_provider.allocate(
      website: @website,
      website_location: @website_location
    )

    @website_event_obj = { title: 'allocate' }

    json(
      status: 'Instance creating...'
    )
  end

  def apply
    result = []

    json(
      status: 'success',
      result: result
    )
  end

  protected

  def requires_active_private_cloud_allocation
    unless @website.private_cloud_allocated?
      validation_error!('The instance requires to be already allocated')
    end
  end
end
