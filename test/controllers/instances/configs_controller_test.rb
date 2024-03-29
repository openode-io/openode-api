# frozen_string_literal: true

require 'test_helper'

class ConfigsControllerTest < ActionDispatch::IntegrationTest
  test '/instances/:instance_id/get-config with valid variable' do
    w = Website.find_by site_name: 'testsite'
    w.configs = { SKIP_PORT_CHECK: 'true' }
    w.save
    get '/instances/testsite/get-config?variable=SKIP_PORT_CHECK',
        as: :json,
        headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['result'], 'success'
    assert_equal response.parsed_body['value'], 'true'
  end

  test '/instances/:instance_id/get-config with invalid variable' do
    get '/instances/testsite/get-config?variable=invalidvar',
        as: :json,
        headers: default_headers_auth
    assert_response :bad_request
  end

  test '/instances/:instance_id/set-config with valid variable, enum, website type' do
    post '/instances/testsite/set-config',
         as: :json,
         params: { variable: 'REDIR_HTTP_TO_HTTPS', value: 'true' },
         headers: default_headers_auth

    assert_response :success

    w = Website.find_by site_name: 'testsite'

    assert_equal w.configs['REDIR_HTTP_TO_HTTPS'], 'true'
    assert_equal w.redir_http_to_https, true
  end

  test '/instances/:instance_id/set-config with TYPE' do
    post '/instances/testsite/set-config',
         as: :json,
         params: { variable: 'TYPE', value: 'kubernetes' },
         headers: default_headers_auth

    assert_response :success
    w = Website.find_by site_name: 'testsite'

    assert_equal w.type, 'kubernetes'
  end

  test '/instances/:instance_id/set-config with EXECUTION_LAYER fail if online' do
    w = Website.find_by site_name: 'testsite'
    w.status = 'online'
    w.save!
    wl = w.website_locations.first
    wl.extra_storage = 0
    wl.save!

    post '/instances/testsite/set-config',
         as: :json,
         params: { variable: 'EXECUTION_LAYER', value: 'kubernetes' },
         headers: default_headers_auth

    assert_response :bad_request
  end

  test '/instances/:instance_id/set-config with EXECUTION_LAYER success if offline' do
    w = Website.find_by site_name: 'testsite'
    w.status = 'N/A'
    w.save!
    wl = w.website_locations.first
    wl.extra_storage = 0
    wl.save!

    post '/instances/testsite/set-config',
         as: :json,
         params: { variable: 'EXECUTION_LAYER', value: 'kubernetes' },
         headers: default_headers_auth

    assert_response :success

    w.reload
    assert_equal w.configs["EXECUTION_LAYER"], "kubernetes"
  end

  test '/instances/:instance_id/set-config with valid variable, enum' do
    post '/instances/testsite/set-config',
         as: :json,
         params: { variable: 'SKIP_PORT_CHECK', value: 'true' },
         headers: default_headers_auth

    assert_response :success
    w = Website.find_by site_name: 'testsite'

    assert_equal w.configs['SKIP_PORT_CHECK'], 'true'
    assert_equal w.skip_port_check?, true
  end

  test '/instances/:instance_id/set-config with valid variable' do
    post '/instances/testsite/set-config',
         as: :json,
         params: { variable: 'SSL_CERTIFICATE_PATH', value: 'path/sub' },
         headers: default_headers_auth

    assert_response :success
    w = Website.find_by site_name: 'testsite'

    assert_equal w.configs['SSL_CERTIFICATE_PATH'], 'path/sub'
  end

  test '/instances/:instance_id/set-config with valid variable, min, max' do
    post '/instances/testsite/set-config',
         as: :json,
         params: { variable: 'MAX_BUILD_DURATION', value: '60' },
         headers: default_headers_auth

    assert_response :success
    w = Website.find_by site_name: 'testsite'

    assert_equal w.configs['MAX_BUILD_DURATION'], '60'

    assert_equal w.events.count, 1
    assert_equal w.events[0].obj['title'], 'Config value changed - MAX_BUILD_DURATION'
  end

  test '/instances/:instance_id/set-config with valid variable, min, max invalid' do
    post '/instances/testsite/set-config',
         as: :json,
         params: { variable: 'MAX_BUILD_DURATION', value: '20' },
         headers: default_headers_auth

    assert_response :unprocessable_entity
  end

  test '/instances/:instance_id/set-config forbidden' do
    w, = prepare_forbidden_test(Website::PERMISSION_PLAN)

    post "/instances/#{w.site_name}/set-config",
         as: :json,
         params: { variable: 'MAX_BUILD_DURATION', value: '20' },
         headers: default_headers_auth

    assert_response :forbidden
  end

  # change multiple configs
  test 'POST /instances/:instance_id/configs - happy path' do
    w = default_website

    post "/instances/#{w.site_name}/configs",
         as: :json,
         params: {
           configs: {
             TYPE: 'kubernetes',
             MAX_BUILD_DURATION: '60'
           }
         },
         headers: default_headers_auth

    assert_response :success

    assert_equal w.reload.type, 'kubernetes'
    assert_equal w.configs['MAX_BUILD_DURATION'], '60'

    assert_includes w.events[0].obj['title'], 'Config values changed'
  end
end
