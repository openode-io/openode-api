class AccountController < ApplicationController

  # get a token given a login-passwd
  def get_token
    json_res(Website::CONFIG_VARIABLES)
  end

  private

end
