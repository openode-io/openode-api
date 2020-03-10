class AccountController < ApplicationController
  before_action only: [:me, :update, :regenerate_token] do
    authorize
  end

  # get a token given a login-passwd
  def get_token
    user = User.find_by! email: params['email']

    user.verify_authentication params['password']

    json("\"#{user.token}\"")
  end

  # returns the logged in user
  def me
    result = @user.attributes
    result['type'] = @user.type

    json(result)
  end

  def register
    user = User.create!(user_params)

    json(
      id: user.id,
      email: user.email,
      token: user.token
    )
  end

  def update
    @user.update!(user_params)

    json(status: 'success')
  end

  def regenerate_token
    @user.regen_api_token!

    # returns back the new token
    json(token: @user.token)
  end

  def forgot_password
    email = params['email']
    user = User.find_by email: email

    unless user
      logger.error("invalid email #{email}")
      return json('status': 'success')
    end

    user.regen_reset_token!

    UserMailer.with(user: user).forgot_password.deliver_now

    json(
      'status': 'success'
    )
  end

  def verify_reset_token
    user = User.find_by! reset_token: params['reset_token']

    # deactivate the token
    user.regen_reset_token!

    json(token: user.token)
  end

  private

  def user_params
    params.require(:account).permit(:email, :password,
                                    :password_confirmation, :newsletter,
                                    :nb_credits_threshold_notification,
                                    account: {})
  end
end
