class ApplicationController < ActionController::API
  include Response
  include ExceptionHandler

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

    authorization_error!("No token provided") unless token

    @user = User.find_by!(token: token)
  end
end
