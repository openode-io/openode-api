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

    assert_equal response.parsed_body[0].keys.sort,
                 %w[id website_id status created_at obj parent_execution_id type].sort
  end

  test '/instances/:instance_id/executions/type with status' do
    w = default_website
    failed_deployment = Deployment.create(website: w, status: 'failed')
    deployments = w.executions.where(type: 'Deployment').where(status: 'success')

    get "/instances/#{w.site_name}/executions/list/Deployment?status=success",
        as: :json,
        headers: default_headers_auth

    assert_response :success
    assert_not deployments.empty?
    assert_equal response.parsed_body.length, deployments.length

    assert_equal response.parsed_body[0].keys.sort,
                 %w[id website_id status created_at obj parent_execution_id type].sort

    ids_response = response.parsed_body.map { |e| e['id'] }
    assert_not_includes ids_response, failed_deployment.id
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
