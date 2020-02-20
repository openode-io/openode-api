require 'test_helper'

class ExecutionsControllerTest < ActionDispatch::IntegrationTest
  test '/instances/:instance_id/executions/type' do
    w = default_website
    deployments = w.executions.where(type: 'Deployment')

    get "/instances/#{w.site_name}/executions/list/Deployment",
        as: :json,
        headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body.length, deployments.length

    assert_equal response.parsed_body[0].keys,
                 %w[id website_id status created_at type]
  end

  test '/instances/:instance_id/executions/id - exists' do
    w = default_website
    execution = w.executions.first

    get "/instances/#{w.site_name}/executions/#{execution.id}",
        as: :json,
        headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['id'], execution.id
    assert_equal response.parsed_body['status'], execution.status
  end
end
