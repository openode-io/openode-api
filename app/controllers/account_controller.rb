class AccountController < ApplicationController
  before_action only: [:me, :update, :regenerate_token,
                       :spendings, :destroy, :friend_invites, :invite_friend] do
    authorize
  end

  # get a token given a login-passwd
  def get_token
    user = User.find_by! email: params['email']

    user.verify_authentication params['password']

    json("\"#{user.token}\"")
  end

  # returns the logged in user
  api :GET, 'account/me'
  description 'Provides the authenticated user information'
  returns code: 200, desc: "" do
    property :id, Integer, desc: "User id"
    property :email, String, desc: "User email"
  end
  def me
    result = @user.attributes
    result['type'] = @user.type
    result['has_active_subscription'] = @user.active_subscription?

    result.delete('password_hash')

    json(result)
  end

  def friend_invites
    json(@user.friend_invites)
  end

  def invite_friend
    friend_invite = FriendInvite.create!(user: @user, status: FriendInvite::STATUS_PENDING,
                                         email: params[:email],
                                         created_by_ip: params[:created_by_ip])
    InviteMailer.with(user: @user, email_to: params[:email]).send_invite.deliver_now

    json(friend_invite)
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

  def destroy
    @user.destroy

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

  api!
  def spendings
    nb_days = (params['nb_days'] || 30).to_i

    hash_entries = CreditAction
                   .where(user_id: @user.id)
                   .where('created_at > ?', nb_days.days.ago)
                   .group("DATE(created_at)")
                   .sum(:credits_spent)

    json(hash_entries.map { |k, v| { date: k, value: v } })
  end

  def activate
    user_to_activate = User.find_by! id: params['user_id'],
                                     activation_hash: params['activation_hash']

    user_to_activate.activated = true
    user_to_activate.save!

    json({})
  end

  private

  def user_params
    params.require(:account).permit(:email, :password,
                                    :password_confirmation, :newsletter,
                                    :nb_credits_threshold_notification,
                                    account: {})
  end
end
