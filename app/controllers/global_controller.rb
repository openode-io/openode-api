
require 'vultr'

class GlobalController < ApplicationController

  def test
    json({})
  end

  def version
    json({
      version: File.read(".version").strip
    })
  end

  def available_locations
    json(CloudProvider::Manager.instance.available_locations)
  end

  def available_plans
    json(CloudProvider::Manager.instance.available_plans)
  end

  def available_plans_at
    manager = CloudProvider::Manager.instance

    json(manager.available_plans_of_type_at(params["type"], params["location_str_id"]))
  end

  def available_configs
    json(Website::CONFIG_VARIABLES)
  end

  def services
    json(Status.all)
  end

  def services_down
    json(Status.with_status("down"))
  end

  private

end
