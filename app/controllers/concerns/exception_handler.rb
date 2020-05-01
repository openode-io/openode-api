module ExceptionHandler
  # provides the more graceful `included` method
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound do |e|
      json({ error: e.message }, :not_found)
    end

    rescue_from ActiveRecord::RecordInvalid do |e|
      json({ error: e.message }, :unprocessable_entity)
    end

    rescue_from ApplicationRecord::ValidationError do |e|
      json({ error: e.message }, :bad_request)
    end

    rescue_from User::NotAuthorized do |e|
      json({ error: e.message }, :unauthorized)
    end

    rescue_from User::TooManyRequests do |e|
      json({ error: e.message }, :too_many_requests)
    end

    rescue_from User::Forbidden do |e|
      json({ error: e.message }, :forbidden)
    end
  end
end
