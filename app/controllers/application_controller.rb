class ApplicationController < ActionController::API
  include Response
  include ExceptionHandler

  def validation_error!(msg)
    raise ApplicationRecord::ValidationError, msg
  end

  def authorization_error!(msg)
    raise User::NotAuthorized, msg
  end
end
