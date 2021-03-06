class ApplicationController < ActionController::API
  include Response
  include ExceptionHandler
  include ApiRateLimit
  include SanitizeRequest

  def validation_error!(msg)
    raise ApplicationRecord::ValidationError, msg
  end

  def authorization_error!(msg)
    raise User::NotAuthorized, msg
  end

  def forbidden_error!(msg)
    raise User::Forbidden, msg
  end

  def authorize
    token = request.headers['x-auth-token'] || params['token']
    origin_request_ip = request.headers['x-origin-request-ip']

    authorization_error!("No token provided") unless token

    @user = User.find_by!(token: token)

    # fail the request if the user is suspended
    authorization_error!("Unauthorized") if @user.suspended?

    # update user updated_at to know which user is active
    threshold_user_should_update = (Time.zone.now - @user.updated_at) / (60 * 60) >= 1

    if threshold_user_should_update
      @user.touch
    end

    if threshold_user_should_update || @user.latest_request_ip.blank?
      @user.update_attribute('latest_request_ip', origin_request_ip)
    end

    rate_limit(@user, response: response)
  end

  def default_listing(model, attributes, opts = {})
    search_for = opts[:search_for] || "%#{params['search']}%"

    model
      .search_for(search_for, attributes)
      .paginate(page: params[:page] || 1, per_page: 100)
      .order(opts[:order] || "id DESC")
  end
end
