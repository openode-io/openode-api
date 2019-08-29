module ExceptionHandler
  # provides the more graceful `included` method
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound do |e|
      json_res({ error: e.message }, :not_found)
    end

    rescue_from ActiveRecord::RecordInvalid do |e|
      json_res({ error: e.message }, :unprocessable_entity)
    end

    rescue_from ApplicationRecord::ValidationError do |e|
      json_res({ error: e.message }, :bad_request)
    end

    rescue_from User::NotAuthorized do |e|
      json_res({ error: e.message }, :unauthorized)
    end
  end
end
