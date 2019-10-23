# frozen_string_literal: true

class ApplicationController < ActionController::API
  include Response
  include ExceptionHandler

  def validation_error!(msg)
    raise ApplicationRecord::ValidationError, msg
  end
end
