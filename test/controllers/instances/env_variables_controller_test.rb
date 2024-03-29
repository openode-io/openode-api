require 'test_helper'

class EnvVariablesControllerTest < ActionDispatch::IntegrationTest
  setup do
  end

  test 'GET /instances/:instance_id/env_variables without variable' do
    w = default_website

    get "/instances/#{w.id}/env_variables",
        as: :json,
        headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body, {}
  end

  test 'GET /instances/:instance_id/env_variables with variables' do
    w = default_website
    w.store_env_variable!('VAR1', 1234)
    w.store_env_variable!('VAR2', 12_345)

    get "/instances/#{w.id}/env_variables",
        as: :json,
        headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body, "VAR1" => 1234, "VAR2" => 12_345
  end

  test 'POST /instances/:instance_id/env_variables/:name - happy path' do
    w = default_website

    post "/instances/#{w.id}/env_variables/VAR1",
         as: :json,
         params: { value: 'test123' },
         headers: default_headers_auth

    post "/instances/#{w.id}/env_variables/VAR2",
         as: :json,
         params: { value: 'test1234' },
         headers: default_headers_auth

    assert_response :success

    w.reload

    assert_equal response.parsed_body, {}
    assert_equal w.env['VAR1'], 'test123'
    assert_equal w.env['VAR2'], 'test1234'

    # then change it
    post "/instances/#{w.id}/env_variables/VAR2",
         as: :json,
         params: { value: 'test12345' },
         headers: default_headers_auth

    assert_equal w.env['VAR2'], 'test12345'
  end

  test 'PUT /instances/:instance_id/env_variables/ - happy path' do
    w = default_website

    w.store_env_variable!('hi', 'world')

    put "/instances/#{w.id}/env_variables/",
        as: :json,
        params: {
          variables: {
            VAR1: 'test123',
            VAR2: 'tteesstt',
            "VAR3 ": 'test3',
            "VAR4\t": 'test4'
          }
        },
        headers: default_headers_auth

    assert_response :success

    w.reload

    assert_equal response.parsed_body, {}
    assert_equal w.env['VAR1'], 'test123'
    assert_equal w.env['VAR2'], 'tteesstt'
    assert_equal w.env['VAR3'], 'test3'
    assert_equal w.env['VAR4'], 'test4'
    assert_equal w.env.keys, %w[VAR1 VAR2 VAR3 VAR4]

    assert_equal w.reload.events.count, 1
    assert_equal w.events.first.obj['title'], 'ENV Variables changed'
  end

  test 'POST /instances/:instance_id/env_variables/ - happy path' do
    w = default_website

    w.store_env_variable!('hi', 'world')

    post "/instances/#{w.id}/env_variables/",
         as: :json,
         params: {
           variables: {
             VAR1: 'test123',
             VAR2: 'tteesstt'
           }
         },
         headers: default_headers_auth

    assert_response :success

    w.reload

    assert_equal response.parsed_body, {}
    assert_equal w.env['VAR1'], 'test123'
    assert_equal w.env['VAR2'], 'tteesstt'
    assert_equal w.env['hi'], 'world'
    assert_equal w.env.keys, %w[hi VAR1 VAR2]

    assert_equal w.reload.events.count, 1
    assert_equal w.events.first.obj['title'], 'ENV Variables changed'
  end

  test 'DELETE /instances/:instance_id/env_variables/:name - happy path' do
    w = default_website

    w.store_env_variable!('HELLO', 'test')

    # then change it
    delete "/instances/#{w.id}/env_variables/HELLO",
           as: :json,
           headers: default_headers_auth

    assert_equal w.env, {}
  end
end
