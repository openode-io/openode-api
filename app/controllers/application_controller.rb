class ApplicationController < ActionController::API

  include Response
  include ExceptionHandler

  def validation_error!(msg)
    raise ApplicationRecord::ValidationError.new(msg)
  end

end
