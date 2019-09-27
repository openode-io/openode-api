
require 'vultr'

class GlobalController < ApplicationController

  def test
    json_res({})
  end

  def version
    json_res({
      version: File.read(".version").strip
    })
  end

  def available_locations
    json_res(CloudProvider::Manager.instance.available_locations)
  end

  def available_plans
    json_res(CloudProvider::Manager.instance.available_plans)
  end

  def available_configs
    json_res(Website::CONFIG_VARIABLES)
  end

  def services
    json_res(Status.all)
  end

  def services_down
    json_res(Status.with_status("down"))
  end

  private

end
