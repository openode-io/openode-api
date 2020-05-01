module ApiRateLimit
  PER_MINUTE_RATE_LIMIT = 250
  HEADER_NAME_REMAINING = 'X-RateLimit-Remaining'
  HEADER_NAME_LIMIT = 'X-RateLimit-Limit'
  HEADER_NAME_RESET = 'X-RateLimit-Reset'

  def self.rate_limit_key(user)
    "api_rate_limit/user-#{user.id}"
  end

  def default_rate_limit_values
    {
      'remaining' => PER_MINUTE_RATE_LIMIT,
      'reset' => Time.zone.now + 1.minute
    }
  end

  def rate_limit_expiration(t_reset)
    Time.zone.now < t_reset ? (t_reset - Time.zone.now).to_i : 0
  end

  def rate_limit(user, args = {})
    key = ApiRateLimit.rate_limit_key(user)

    api = Rails.cache.fetch(key, expires_in: 1.minute) do
      default_rate_limit_values
    end

    # reset the date when it's now larger
    if Time.zone.now >= api['reset']
      set_headers_rate_limit(key: key, api: default_rate_limit_values,
                             response: args[:response])
      return Rails.cache.delete(key)
    end

    raise User::TooManyRequests, "Too many requests" if api['remaining']&.zero?

    api['remaining'] -= 1 if api['remaining']

    Rails.cache.write(key, api, expires_in: rate_limit_expiration(api['reset']))
    set_headers_rate_limit(key: key, api: api, response: args[:response])
  end

  def set_headers_rate_limit(args = {})
    Rails.logger.info("rate_limit (#{args[:key]}) - #{args[:api].inspect}")

    args[:response].set_header(HEADER_NAME_REMAINING,
                               args[:api]['remaining'] || PER_MINUTE_RATE_LIMIT)
    args[:response].set_header(HEADER_NAME_LIMIT, PER_MINUTE_RATE_LIMIT)
    args[:response].set_header(HEADER_NAME_RESET,
                               args[:api]['reset']&.to_i || Time.zone.now + 1.minute)
  end
end
