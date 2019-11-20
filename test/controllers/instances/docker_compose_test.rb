# frozen_string_literal: true

require 'test_helper'

class DeploymentMethodDockerComposeTest < ActionDispatch::IntegrationTest
  test '/instances/:instance_id/docker-compose ' do
    get '/instances/testsite/docker-compose',
        as: :json,
        headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['content'].include?("version: '3'"), true
    assert_equal response.parsed_body['content'].include?('# env_file'), true
  end

  test '/instances/:instance_id/docker-compose with env file' do
    get '/instances/testsite/docker-compose?has_env_file=true',
        as: :json,
        headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['content'].include?("version: '3'"), true
    assert_equal response.parsed_body['content'].include?('    env_file:'), true
  end

  test '/instances/:instance_id/docker-compose with env file env file false' do
    get '/instances/testsite/docker-compose?has_env_file=false',
        as: :json,
        headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['content'].include?('# env_file'), true
  end
end
