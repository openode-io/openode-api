require 'vultr'

class GlobalController < ApplicationController
  api!
  def test
    json({})
  end

  api!
  def version
    json(
      version: File.read('.version').strip
    )
  end

  api!
  def available_locations
    json(CloudProvider::Manager.instance.available_locations)
  end

  api!
  def available_plans
    json(CloudProvider::Manager.instance.available_plans)
  end

  api!
  def available_plans_at
    manager = CloudProvider::Manager.instance

    json(manager.available_plans_of_type_at(params['type'], params['location_str_id']))
  end

  api!
  def available_configs
    json(Website::CONFIG_VARIABLES)
  end

  api!
  def services
    json(Status.all)
  end

  api!
  def services_down
    json(Status.with_status('down'))
  end

  api!
  def settings
    json(SystemSetting.global_msg.content || {})
  end
end
