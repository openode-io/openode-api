# frozen_string_literal: true

class PrivateCloudController < InstancesController
  before_action only: [:allocate] do
    requires_private_cloud_plan
  end

  def allocate
    if @website.data && @website.data['privateCloudInfo']
      return json(success: 'Instance already allocated')
    end

    unless @website.user.has_credits?
      raise ApplicationRecord::ValidationError, 'No credit available'
    end

    cloud_provider = CloudProvider::Manager.instance.first_of_internal_type(CloudProvider::Vultr::TYPE)

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
