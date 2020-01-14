# frozen_string_literal: true

require 'test_helper'

class InstancesControllerDeployDockerTest < ActionDispatch::IntegrationTest
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
      run_deployer_job

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
      run_deployer_job

      deployment = website.deployments.last
      website.reload

      assert_equal website.status, Website::STATUS_OFFLINE
      assert_equal deployment.status, Deployment::STATUS_FAILED
      assert_equal deployment.result['steps'].length, 5 # global, 2 kills, finalize

      assert_includes deployment.result['errors'][0]['title'], 'User account not yet activated'
    end
  end

  test '/instances/:instance_id/restart should not allow when user suspended' do
    dep_method = prepare_default_execution_method

    website = default_website
    website.user.suspended = true
    website.user.save

    prepare_default_ports

    post '/instances/testsite/restart',
         as: :json,
         params: base_params,
         headers: default_headers_auth

    prepare_logs_container(dep_method, website, '123456789', 'done logs')

    prepare_default_kill_all(dep_method)

    assert_scripted do
      begin_ssh
      run_deployer_job

      deployment = website.deployments.last
      website.reload

      assert_equal website.status, Website::STATUS_OFFLINE
      assert_equal deployment.status, Deployment::STATUS_FAILED
      assert_equal deployment.result['steps'].length, 5 # global, 2 kills, finalize

      assert_includes deployment.result['errors'][0]['title'], 'User suspended'
    end
  end

  test '/instances/:instance_id/restart - happy path' do
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

    prepare_ssh_session(dep_method.instance_up_cmd(website_location: website_location), '')

    prepare_logs_container(dep_method, website, 'b3621dd9d4dd', 'done logs')

    expect_global_container(dep_method)
    prepare_ssh_session(dep_method.kill_global_container(id: '32bfe26a2712'), 'killed 32bfe26a2712')

    assert_scripted do
      begin_ssh
      run_deployer_job

      deployment = website.deployments.last
      website.reload

      assert_equal website.status, Website::STATUS_ONLINE
      assert_equal deployment.status, Deployment::STATUS_SUCCESS
      assert_equal deployment.result['steps'].length, 17 # global, 2 kills, finalize

      assert_equal deployment.result['errors'].length, 0

      # should also have a deployment with events
      assert_equal website.deployments.last.events.length, 17

      allowed_to = dep_event_exists?(website.deployments.last.events,
                                     'running', 'allowed to dep')
      assert_equal allowed_to, true

      verified_event = dep_event_exists?(website.deployments.last.events,
                                         'running', '...verified')
      assert_equal verified_event, true

      initializing_event = dep_event_exists?(website.deployments.last.events,
                                             'running', 'Initializing')
      assert_equal initializing_event, true

      building_image_event = dep_event_exists?(website.deployments.last.events,
                                               'running', 'Building the instance')
      assert_equal building_image_event, true

      building_image_done_event = dep_event_exists?(website.deployments.last.events,
                                                    'running', 'image built')
      assert_equal building_image_done_event, true

      verif_instance_up_event = dep_event_exists?(website.deployments.last.events,
                                                  'running', 'Verifying instance up')
      assert_equal verif_instance_up_event, true

      verif_instance_done_event = dep_event_exists?(website.deployments.last.events,
                                                    'running', 'instance verification finished')
      assert_equal verif_instance_done_event, true

      done_log_exists = dep_event_exists?(website.deployments.last.events,
                                          'success', 'done logs')
      assert_equal done_log_exists, true

      finalized_event = dep_event_exists?(website.deployments.last.events,
                                          'success', '...finalized')
      assert_equal finalized_event, true

      final_details_event = website.deployments.last.events.find do |e|
        e['update'].andand['details'].andand['result']
      end

      assert_not_nil final_details_event
      assert_equal(final_details_event['update']['details']['url'],
                   "http://testsite.#{CloudProvider::Manager.base_hostname}/")
    end
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
      run_deployer_job

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

      run_deployer_job

      deployment = website.deployments.last
      website.reload

      assert_equal website.status, Website::STATUS_OFFLINE
      assert_equal deployment.status, Deployment::STATUS_FAILED
    end
  end

  test '/instances/:instance_id/restart - SKIP_PORT_CHECK' do
    dep_method = prepare_default_execution_method
    website = default_website
    website.crontab = ''
    website.configs = {}
    website.configs['SKIP_PORT_CHECK'] = 'true'
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

    prepare_logs_container(dep_method, website, 'b3621dd9d4dd', 'done logs')

    expect_global_container(dep_method)

    prepare_ssh_session(dep_method.kill_global_container(id: '32bfe26a2712'), 'killed 32bfe26a2712')

    assert_scripted do
      begin_ssh

      run_deployer_job

      deployment = website.deployments.last
      website.reload

      assert_equal website.status, Website::STATUS_ONLINE
      assert_equal deployment.status, Deployment::STATUS_SUCCESS
    end
  end
end
