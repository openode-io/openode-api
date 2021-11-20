# frozen_string_literal: true

require 'test_helper'

class InstancesControllerDeployDockerTest < ActionDispatch::IntegrationTest
  setup do
    clear_all_queued_jobs
  end

  test '/instances/:instance_id/restart should not allow when no credit' do
    dep_method = prepare_default_execution_method

    website = default_website
    website.user.credits = 0
    website.user.save

    prepare_default_ports

    post '/instances/testsite/restart',
         as: :json,
         params: base_params,
         headers: default_headers_auth

    assert_response :success

    prepare_logs_container(dep_method, website, '123456789', 'done logs')

    prepare_default_kill_all(dep_method)

    assert_scripted do
      begin_ssh
      invoke_all_jobs

      deployment = website.deployments.last
      website.reload

      assert_equal website.status, Website::STATUS_OFFLINE
      assert_equal deployment.status, Deployment::STATUS_FAILED
      assert_equal deployment.result['steps'].length, 5 # global, 2 kills, finalize

      assert_includes deployment.result['errors'][0]['title'], 'No credit'
    end
  end

  test '/instances/:instance_id/restart should not allow when user not activated' do
    dep_method = prepare_default_execution_method

    website = default_website
    website.user.activated = false

    user = website.user
    user.email = "myinvalidemail@gmail.com"
    user.save!

    website.user.save

    prepare_default_ports

    post '/instances/testsite/restart',
         as: :json,
         params: base_params,
         headers: default_headers_auth

    assert_response :success

    prepare_logs_container(dep_method, website, '123456789', 'done logs')

    prepare_default_kill_all(dep_method)

    assert_scripted do
      begin_ssh
      invoke_all_jobs

      deployment = website.deployments.last
      website.reload

      assert_equal website.status, Website::STATUS_OFFLINE
      assert_equal deployment.status, Deployment::STATUS_FAILED
      assert_equal deployment.result['steps'].length, 5 # global, 2 kills, finalize

      assert_includes deployment.result['errors'][0]['title'], 'User account not yet activated'
    end
  end

  test '/instances/:instance_id/restart should not allow when user suspended' do
    website = default_website
    website.user.suspended = true
    website.user.save

    prepare_default_ports

    post '/instances/testsite/restart',
         as: :json,
         params: base_params,
         headers: default_headers_auth

    assert_response :unauthorized
  end

  test '/instances/:instance_id/restart - missing credits' do
    prepare_default_execution_method
    website = default_website
    website.crontab = ''
    website.save

    website.user.credits = 0
    website.user.save!

    website_location = default_website_location

    prepare_default_ports
    website.reload
    website_location.reload

    post '/instances/testsite/restart',
         as: :json,
         params: base_params,
         headers: default_headers_auth

    assert_scripted do
      begin_ssh
      invoke_all_jobs

      deployment = website.deployments.last
      website.reload

      assert_equal website.status, Website::STATUS_OFFLINE
      assert_equal deployment.status, Deployment::STATUS_FAILED

      credit_error = deployment.result['errors'].first
      assert_includes credit_error['title'], 'No credit available'
    end
  end

  test '/instances/:instance_id/restart - not listening on proper port' do
    dep_method = prepare_default_execution_method
    website = default_website
    website.crontab = ''
    website.save
    website_location = default_website_location

    prepare_default_ports
    website.reload
    website_location.reload

    post '/instances/testsite/restart',
         as: :json,
         params: base_params,
         headers: default_headers_auth

    prepare_get_docker_compose(dep_method, website)
    prepare_ssh_session(dep_method.prepare_dind_compose_image, 'empty')
    expect_global_container(dep_method)
    prepare_ssh_session(dep_method.kill_global_container(id: 'b3621dd9d4dd'), 'killed b3621dd9d4dd')
    prepare_front_container(dep_method, website, website_location, '')
    expect_global_container(dep_method)

    prepare_docker_compose(dep_method, 'b3621dd9d4dd', '')
    prepare_ssh_session(dep_method.ps(front_container_id: 'b3621dd9d4dd'),
                        IO.read('test/fixtures/docker/docker-compose-ps.txt'))

    prepare_ssh_session(dep_method.instance_up_cmd(website_location: website_location), '', 1)

    prepare_logs_container(dep_method, website, 'b3621dd9d4dd', 'done logs')

    expect_global_container(dep_method)

    prepare_ssh_session(dep_method.kill_global_container(id: 'b3621dd9d4dd'), 'killed b3621dd9d4dd')
    prepare_ssh_session(dep_method.kill_global_container(id: '32bfe26a2712'), 'killed 32bfe26a2712')

    assert_scripted do
      begin_ssh

      invoke_all_jobs

      deployment = website.deployments.last
      website.reload

      assert_equal website.status, Website::STATUS_OFFLINE
      assert_equal deployment.status, Deployment::STATUS_FAILED
    end
  end
end
