class AccountController < ApplicationController

  # get a token given a login-passwd
  def get_token
    user = User.find_by! email: params["email"]

    user.authenticate! params["password"]

    json_res("\"#{user.token}\"")
  end

  private

end
