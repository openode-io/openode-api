require 'test_helper'

class RateLimitTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test 'Single query, 2 users' do
    user = default_user
    user2 = User.where("id != ?", user.id).first

    Rails.cache.delete(ApiRateLimit.rate_limit_key(user))
    Rails.cache.delete(ApiRateLimit.rate_limit_key(user2))

    # user 1
    get "/instances/", as: :json, headers: default_headers_auth

    assert_response :success

    assert_equal response.headers['X-RateLimit-Remaining'],
                 (ApiRateLimit::PER_MINUTE_RATE_LIMIT - 1)
    assert_equal response.headers['X-RateLimit-Limit'], ApiRateLimit::PER_MINUTE_RATE_LIMIT
    assert_equal response.headers['X-RateLimit-Reset'].class, Integer

    # user 2
    get "/instances/", as: :json, headers: headers_auth(user2.token)

    assert_response :success

    assert_equal response.headers['X-RateLimit-Remaining'],
                 (ApiRateLimit::PER_MINUTE_RATE_LIMIT - 1)
    assert_equal response.headers['X-RateLimit-Limit'], ApiRateLimit::PER_MINUTE_RATE_LIMIT
    assert_equal response.headers['X-RateLimit-Reset'].class, Integer
  end

  test 'Multiple queries' do
    user = default_user

    Rails.cache.delete(ApiRateLimit.rate_limit_key(user))

    nb_queries = 10

    freeze_time do
      (1..nb_queries).each do |cur_i_query|
        get "/instances/", as: :json, headers: default_headers_auth

        assert_response :success

        assert_equal response.headers['X-RateLimit-Remaining'],
                     (ApiRateLimit::PER_MINUTE_RATE_LIMIT - cur_i_query)
        assert_equal response.headers['X-RateLimit-Limit'],
                     ApiRateLimit::PER_MINUTE_RATE_LIMIT
        assert_equal response.headers['X-RateLimit-Reset'], Time.zone.now.to_i + 60
      end
    end
  end

  test 'Too many queries' do
    user = default_user

    Rails.cache.delete(ApiRateLimit.rate_limit_key(user))

    nb_queries = ApiRateLimit::PER_MINUTE_RATE_LIMIT + 1

    (1..nb_queries).each do
      get "/instances/", as: :json, headers: default_headers_auth
    end

    assert_response :too_many_requests

    travel 1.minute do
      get "/instances/", as: :json, headers: default_headers_auth
      assert_response :success

      assert_not response.parsed_body.empty?
    end
  end
end
