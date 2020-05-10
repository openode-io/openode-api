
require 'test_helper'

class GlobalControllerTest < ActionDispatch::IntegrationTest
  test '/global/test' do
    get '/global/test', as: :json

    assert_response :success
  end

  test '/global/status/job-queues - not full' do
    get '/global/status/job-queues', as: :json

    assert_response :success
  end

  test '/global/status/job-queues - full' do
    (1..Deployment::NB_JOB_QUEUES + 6).each do
      post "/instances/#{default_website.site_name}/restart",
           as: :json,
           params: base_params,
           headers: default_headers_auth
    end

    get '/global/status/job-queues', as: :json

    assert_response :internal_server_error
  end

  test '/documentation' do
    get '/documentation'

    assert_response :success

    assert_includes response.parsed_body, 'Official opeNode API documentation'
  end

  test '/global/available-configs' do
    get '/global/available-configs', as: :json

    assert_response :success

    expected_variables = %w[
      SSL_CERTIFICATE_PATH
      SSL_CERTIFICATE_KEY_PATH
      REDIR_HTTP_TO_HTTPS
      MAX_BUILD_DURATION
      SKIP_PORT_CHECK
    ]

    expected_variables.each do |var|
      assert_equal response.parsed_body.any? { |v| v['variable'] == var }, true
    end
  end

  test '/global/available-plans' do
    get '/global/available-plans', as: :json

    assert_response :success

    assert_equal response.parsed_body.length, 8
    dummy = response.parsed_body.find { |l| l['id'] == 'DUMMY-PLAN' }
    assert_equal dummy['id'], 'DUMMY-PLAN'

    cloud = response.parsed_body.find { |l| l['id'] == '100-MB' }
    assert_equal cloud['id'], '100-MB'
  end

  test '/global/available-plans-at internal' do
    get '/global/available-plans-at/cloud/canada', as: :json

    assert_response :success

    assert_equal response.parsed_body.length, 7
    assert_equal response.parsed_body[0]['id'], 'open-source'
  end

  test '/global/version' do
    get '/global/version', as: :json

    assert_response :success
    assert response.parsed_body['version'].count('.'), 2
  end

  test '/global/services' do
    get '/global/services', as: :json

    assert_response :success
    assert response.parsed_body.length, 2
    assert response.parsed_body[0]['name'], 'Mongodb'
    assert response.parsed_body[1]['name'], 'docker canada'
  end

  test '/global/services/down' do
    get '/global/services/down', as: :json

    assert_response :success
    assert response.parsed_body.length, 1
    assert response.parsed_body[0]['name'], 'docker canada'
  end

  # settings
  test '/global/settings if never set' do
    get '/global/settings', as: :json

    assert_response :success
    assert_equal response.parsed_body, {}
  end

  test '/global/settings if set' do
    GlobalNotification.create!(
      level: Notification::LEVEL_PRIORITY,
      content: 'issue happening'
    )

    get '/global/settings', as: :json

    assert_response :success
    assert_equal(response.parsed_body,
                 "global_msg" => "issue happening",
                 "global_msg_class" => "danger")
  end

  test '/global/stats' do
    get '/global/stats', as: :json

    assert_response :success
    assert_equal(response.parsed_body,
                 "nb_users" => User.count, "nb_deployments" => Deployment.total_nb)
  end
end
