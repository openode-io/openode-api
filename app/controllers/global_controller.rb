
require 'vultr'

class GlobalController < ApplicationController

  def test
    json_res({})
  end

  def available_locations
    json_res(CloudProvider::Manager.instance.available_locations)
  end

  def available_configs
    json_res(Website::CONFIG_VARIABLES)
  end

  private

end
