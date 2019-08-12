class GlobalController < ApplicationController

  def available_configs
    json_res(Website::CONFIG_VARIABLES)
  end

  private

end
