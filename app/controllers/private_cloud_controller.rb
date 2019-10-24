# frozen_string_literal: true

class PrivateCloudController < InstancesController
  before_action only: [:allocate] do
    requires_private_cloud_plan
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
end
