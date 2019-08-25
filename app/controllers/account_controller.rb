class AccountController < ApplicationController

  # get a token given a login-passwd
  def get_token
    user = User.find_by! email: params["email"]

    user.verify_authentication params["password"]

    json_res("\"#{user.token}\"")
  end

  def register
    user = User.create!(user_params)

    UserMailer.with(user: user).registration.deliver_now

    json_res({
      id: user.id,
      email: user.email,
      token: user.token
    })
  end

  private

  def user_params
    params.require(:account).permit(:email, :password, :password_confirmation, :newsletter)
  end

end
