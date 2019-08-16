class GlobalController < ApplicationController

  def test
    json_res({})
  end

  def available_configs
    json_res(Website::CONFIG_VARIABLES)
  end

  private

end
