
require 'vultr'

class GlobalController < ApplicationController

  def test
    json_res({})
  end

  def available_locations

    #regions = Vultr::Regions.list
    #puts "regions ?! #{regions.inspect}"

    locations = Location.all.order(created_at: :asc).map do |l|
      {
        id: l.str_id,
        name: l.full_name,
        country_fullname: l.country_fullname
      }
    end

    json_res(locations)
  end

  def available_configs
    json_res(Website::CONFIG_VARIABLES)
  end

  private

end
