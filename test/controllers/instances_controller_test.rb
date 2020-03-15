# frozen_string_literal: true

require 'test_helper'

class InstancesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test '/instances/ with param token' do
    user = default_user

    get "/instances/?token=#{user.token}", as: :json

    assert_response :success
    assert_equal response.parsed_body.length, 3
    assert_equal response.parsed_body[0]['site_name'], 'testkubernetes-type'
    assert_equal response.parsed_body[0]['status'], 'online'
  end

  test '/instances/ with header token' do
    w = Website.find_by site_name: 'testsite'
    w.domains = []
    w.save
    get '/instances/', as: :json, headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body.length, 3

    w_found = response.parsed_body.find { |cur| cur['site_name'] == 'testsite' }
    assert_equal w_found['site_name'], 'testsite'
    assert_equal w_found['status'], 'online'
    assert_equal w_found['domains'], []
  end

  test '/instances/ with null token should fail' do
    w = Website.find_by site_name: 'testsite'
    w.domains = []
    w.save
    get '/instances/', as: :json, headers: { "x-auth-token": nil }

    assert_response :unauthorized
  end

  test '/instances/ with valid API version (equal to)' do
    InstancesController::MINIMUM_CLI_VERSION = '2.0.1'
    get '/instances/?version=2.0.1', as: :json, headers: default_headers_auth

    assert_response :success
  end

  test '/instances/ with valid API version (greater than)' do
    InstancesController::MINIMUM_CLI_VERSION = '2.0.1'
    get '/instances/?version=2.2.2', as: :json, headers: default_headers_auth

    assert_response :success
  end

  test '/instances/ happy path' do
    get '/instances/', as: :json, headers: default_headers_auth

    assert_response :success

    user = User.find_by! token: "1234s56789"

    assert_equal response.parsed_body.length, user.websites_with_access.length

    user.websites_with_access.each do |w|
      site_exists = response.parsed_body.any? { |cur| cur['site_name'] == w.site_name }
      assert_equal(site_exists, true)
    end
  end

  test '/instances/ with one as collaborator' do
    user = User.find_by! token: "1234s56789"
    assert_equal user.websites_with_access.map(&:site_name),
                 %w[testkubernetes-type testsite testprivatecloud]

    new_site = Website.find_by! site_name: "testsite2"

    Collaborator.create(
      user: user,
      website: new_site,
      permissions: [Website::PERMISSION_ROOT]
    )

    get '/instances/', as: :json, headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body.length, 4

    %w[testkubernetes-type testsite testprivatecloud testsite2].each do |site_name|
      site_exists = response.parsed_body.any? { |cur| cur['site_name'] == site_name }
      assert_equal(site_exists, true)
    end
  end

  test '/instances/ with deprecated api version' do
    InstancesController::MINIMUM_CLI_VERSION = '2.0.1'
    get '/instances/?version=1.0.1', as: :json, headers: default_headers_auth

    assert_response :bad_request
  end

  test '/instances/:instance_id with valid site name' do
    get '/instances/testsite', as: :json, headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['site_name'], 'testsite'
    assert_equal response.parsed_body['status'], 'online'
  end

  test '/instances/:instance_id with id instead of site name' do
    w = default_website

    get "/instances/#{w.id}", as: :json, headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['site_name'], 'testsite'
    assert_equal response.parsed_body['status'], 'online'
  end

  test '/instances/summary happy path' do
    website = Website.find_by site_name: 'testsite'
    get '/instances/summary', as: :json, headers: default_headers_auth

    assert_response :success

    site_to_check = response.parsed_body.find { |w| w['site_name'] == website.site_name }
    assert_equal site_to_check['site_name'], 'testsite'
    assert_equal site_to_check['ip'], '127.0.0.1'
    assert_equal site_to_check['location']['full_name'], 'Montreal (Canada)'
    assert_equal site_to_check['price'], '0.80'
    assert_equal site_to_check['plan_name'], '100 MB'
    assert_equal site_to_check['nb_collaborators'], website.collaborators.count
    assert_equal site_to_check['last_deployment_id'], website.deployments.last.id
  end

  test '/instances/summary happy path without last deployment' do
    website = Website.find_by site_name: 'testsite'

    website.deployments.each(&:destroy)

    get '/instances/summary', as: :json, headers: default_headers_auth

    assert_response :success

    site_to_check = response.parsed_body.find { |w| w['site_name'] == website.site_name }
    assert_equal site_to_check['site_name'], 'testsite'
    assert_equal site_to_check['last_deployment_id'], nil
  end

  test '/instances/:instance_id with custom domain' do
    user = default_user
    site = Website.find_by! site_name: 'www.what.is'

    Collaborator.create(
      user: user,
      website: site,
      permissions: [Website::PERMISSION_ROOT]
    )

    get '/instances/www.what.is', as: :json, headers: default_headers_auth

    assert_response :success
  end

  test '/instances/:instance_id failing to have access to website' do
    get '/instances/www.what.is', as: :json, headers: default_headers_auth

    assert_response :unauthorized
  end

  test '/instances/:instance_id with non existent site name' do
    get '/instances/testsite10', as: :json, headers: default_headers_auth

    assert_response :not_found
  end

  # create
  test '/instances/create with valid information' do
    post '/instances/create',
         params: { site_name: 'helloworld123', account_type: 'second' },
         as: :json,
         headers: default_headers_auth

    assert_response :success
    assert_equal !response.parsed_body['id'].nil?, true

    website = Website.find(response.parsed_body['id'])

    assert_equal website.id, response.parsed_body['id']
    assert_equal website.site_name, 'helloworld123'
    assert_equal website.domain_type, 'subdomain'
  end

  test '/instances/create with open source' do
    post '/instances/create',
         params: {
           site_name: 'helloworld123',
           account_type: 'open_source',
           open_source_title: 'helloworld',
           open_source_description: 'asdf ' * 50,
           open_source_repository: 'http://google.com/'
         },
         as: :json,
         headers: default_headers_auth

    assert_response :success

    website = Website.find(response.parsed_body['id'])

    assert_equal website.id, response.parsed_body['id']
    assert_equal website.account_type, 'open_source'
    assert_equal website.site_name, 'helloworld123'
    assert_equal website.domain_type, 'subdomain'
    assert_equal website.open_source['status'], Website::OPEN_SOURCE_STATUS_PENDING
    assert_equal website.open_source['title'], 'helloworld'
    assert_equal website.open_source['description'], 'asdf ' * 50
    assert_equal website.open_source['repository_url'], 'http://google.com/'
  end

  test '/instances/create with initial location' do
    post '/instances/create',
         params: {
           site_name: 'helloworld123',
           account_type: 'second',
           location: 'canada'
         },
         as: :json,
         headers: default_headers_auth

    assert_response :success
    assert_equal !response.parsed_body['id'].nil?, true

    website = Website.find(response.parsed_body['id'])

    assert_equal website.id, response.parsed_body['id']

    assert_equal website.website_locations.first.location.str_id, 'canada'
  end

  test '/instances/create with invalid' do
    post '/instances/create',
         params: { site_name: '..', account_type: 'second' },
         as: :json,
         headers: default_headers_auth

    assert_response :unprocessable_entity
  end

  test '/instances/create with invalid account type' do
    post '/instances/create',
         params: { site_name: 'hello1234', account_type: 'second2' },
         as: :json,
         headers: default_headers_auth

    assert_response :unprocessable_entity
  end

  # /changes
  test '/instances/:instance_id/changes with one file deleted' do
    set_dummy_secrets_to(LocationServer.all)

    website = Website.find_by site_name: 'testsite'

    cmd = DeploymentMethod::DockerCompose.new.files_listing(path: website.repo_dir)

    prepare_ssh_session(cmd, '[{"path":"test/what.txt","type":"F","checksum":"123456"},' \
      '{"path":"test/what2.txt","type":"F","checksum":"123457"}]')

    assert_scripted do
      begin_ssh
      post '/instances/testsite/changes?location_str_id=canada',
           params: { files: '[{"path":"test/what.txt","type":"F","checksum":"123456"}]' },
           as: :json,
           headers: default_headers_auth

      assert_response :success
      assert_equal response.parsed_body.length, 1
      assert_equal response.parsed_body[0]['path'], 'test/what2.txt'
      assert_equal response.parsed_body[0]['change'], 'D'
    end
  end

  # send_compressed_file
  test '/instances/:instance_id/send_compressed_file ' do
    set_dummy_secrets_to(LocationServer.all)
    file_to_upload = fixture_file_upload('files/small_repo.zip')

    website = Website.find_by site_name: 'testsite'

    prepare_ssh_ensure_remote_repository(website)
    prepare_send_remote_repo(website, 'small_repo.zip', 'all ok')

    assert_scripted do
      begin_sftp
      begin_ssh
      post '/instances/testsite/sendCompressedFile?location_str_id=canada',
           params: { file: file_to_upload },
           headers: default_headers_auth

      assert_response :success
      assert_equal response.parsed_body['result'], 'success'
    end
  end

  # /delete_files
  test '/instances/:instance_id/deleteFiles ' do
    set_dummy_secrets_to(LocationServer.all)

    website = Website.find_by site_name: 'testsite'

    docker_compose_instance = DeploymentMethod::DockerCompose.new
    cmd = docker_compose_instance.delete_files(files: ["#{website.repo_dir}./test.txt",
                                                       "#{website.repo_dir}./test2.txt"])
    prepare_ssh_session(cmd, '')

    assert_scripted do
      begin_sftp
      begin_ssh

      files = [
        { 'path' => './test.txt' },
        { 'path' => './test2.txt' }
      ]

      delete '/instances/testsite/deleteFiles?location_str_id=canada',
             params: { filesInfo: files },
             headers: default_headers_auth

      assert_response :success
      assert_equal response.parsed_body['result'], 'success'
    end
  end

  # /logs with docker compose
  test '/instances/:instance_id/logs with subdomain' do
    set_dummy_secrets_to(LocationServer.all)

    prepare_ssh_session('docker exec 123456789 docker-compose logs --tail=100',
                        'hellooutput')

    assert_scripted do
      begin_ssh
      get '/instances/testsite/logs?location_str_id=canada',
          as: :json,
          headers: default_headers_auth

      assert_response :success
      assert_equal response.parsed_body['logs'], 'hellooutput'
    end
  end

  # /cmd with docker compose
  test '/instances/:instance_id/cmd with subdomain' do
    set_dummy_secrets_to(LocationServer.all)

    prepare_ssh_session('docker exec 123456789 docker-compose exec -T  www ls -la',
                        'hellooutput')

    assert_scripted do
      begin_ssh
      post '/instances/testsite/cmd?location_str_id=canada',
           as: :json,
           params: { service: 'www', cmd: 'ls -la' },
           headers: default_headers_auth

      assert_response :success
      assert_equal response.parsed_body['result']['stdout'], 'hellooutput'
    end
  end

  test '/instances/:instance_id/cmd fail if offline' do
    set_dummy_secrets_to(LocationServer.all)
    website = Website.find_by! site_name: 'testsite'

    website.change_status!(Website::STATUS_OFFLINE)

    assert_scripted do
      begin_ssh
      post '/instances/testsite/cmd?location_str_id=canada',
           as: :json,
           params: { service: 'www', cmd: 'ls -la' },
           headers: default_headers_auth

      assert_response :bad_request
    end
  end

  # stop with docker compose internal
  test '/instances/:instance_id/stop with internal' do
    dep_method = prepare_default_execution_method
    set_dummy_secrets_to(LocationServer.all)
    prepare_default_ports
    website = default_website

    expect_global_container(dep_method)
    prepare_ssh_session(dep_method.kill_global_container(id: 'b3621dd9d4dd'),
                        'killed b3621dd9d4dd')
    prepare_ssh_session(dep_method.kill_global_container(id: '32bfe26a2712'),
                        'killed 32bfe26a2712')

    assert_scripted do
      begin_ssh
      post '/instances/testsite/stop?location_str_id=canada',
           as: :json,
           params: {},
           headers: default_headers_auth

      assert_response :success
      assert_equal response.parsed_body['result'], 'success'

      assert_equal website.executions.last.type, 'Task'
    end
  end

  test '/instances/:instance_id/stop should fail if offline' do
    website = default_website
    website.status = Website::STATUS_OFFLINE
    website.save!

    post '/instances/testsite/stop?location_str_id=canada',
         as: :json,
         params: {},
         headers: default_headers_auth

    assert_response :bad_request
    assert_includes response.parsed_body.to_s, "must be in status"
  end

  test '/instances/:instance_id/stop forbidden' do
    w, = prepare_forbidden_test(Website::PERMISSION_PLAN)

    post "/instances/#{w.site_name}/stop?location_str_id=usa",
         as: :json,
         headers: default_headers_auth

    assert_response :forbidden
  end

  # reload with docker compose internal
  test '/instances/:instance_id/reload with internal' do
    dep_method = prepare_default_execution_method
    set_dummy_secrets_to(LocationServer.all)
    prepare_default_ports

    prepare_ssh_session(dep_method.down(front_container_id: '123456789'), '123456789')
    prepare_ssh_session(dep_method.docker_compose(front_container_id: '123456789'),
                        '123456789')

    assert_scripted do
      begin_ssh

      post '/instances/testsite/reload?location_str_id=canada',
           as: :json,
           params: {},
           headers: default_headers_auth

      Delayed::Job.first.invoke_job

      assert_response :success
      assert_equal response.parsed_body['result'], 'success'
      assert_equal Deployment.last.status, Deployment::STATUS_SUCCESS
    end
  end

  test '/instances/:instance_id/reload not available for kubernetes' do
    post "/instances/#{default_kube_website.site_name}/reload?location_str_id=canada",
         as: :json,
         params: {},
         headers: default_headers_auth

    assert_response :bad_request
  end

  # /erase-all with docker compose
  test '/instances/:instance_id/erase-all typical scenario' do
    set_dummy_secrets_to(LocationServer.all)

    website = Website.find_by! site_name: 'testsite'
    path_repo = "#{Website::REPOS_BASE_DIR}#{website.user_id}/#{website.site_name}/"
    prepare_ssh_session("rm -rf #{path_repo}", 'out1')
    prepare_ssh_session("mkdir -p #{path_repo}", 'out2')

    assert_scripted do
      begin_ssh
      post '/instances/testsite/erase-all?location_str_id=canada',
           as: :json,
           headers: default_headers_auth

      assert_response :success
      assert_equal response.parsed_body['result'], 'success'

      assert_equal website.events.count, 1
      assert_equal website.events[0].obj['title'], 'Repository cleared (erase-all)'
    end
  end

  # /plan
  test '/instances/:instance_id/plan second' do
    get '/instances/testsite/plan?location_str_id=canada',
        as: :json,
        headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['id'], '100-MB'
    assert_equal response.parsed_body['name'], '100MB Memory'
  end

  # /plans
  test '/instances/:instance_id/plans cloud' do
    get '/instances/testsite/plans?location_str_id=canada',
        as: :json,
        headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body.length, 8
    assert_equal response.parsed_body[0]['id'], 'sandbox'
  end

  # /set-plan
  test '/instances/:instance_id/set-plan to a new one' do
    dep_method = prepare_default_execution_method
    set_dummy_secrets_to(LocationServer.all)
    prepare_default_ports

    website = default_website

    expect_global_container(dep_method)
    prepare_ssh_session(dep_method.kill_global_container(id: 'b3621dd9d4dd'),
                        'killed b3621dd9d4dd')
    prepare_ssh_session(dep_method.kill_global_container(id: '32bfe26a2712'),
                        'killed 32bfe26a2712')

    assert_scripted do
      begin_ssh
      post '/instances/testsite/set-plan', # works without location str id
           as: :json,
           params: { plan: '100-MB' },
           headers: default_headers_auth

      assert_response :success

      Delayed::Job.first.invoke_job
      website.reload
      assert_equal website.account_type, 'second'
      assert_equal website.cloud_type, 'cloud'
    end
  end

  test '/instances/:instance_id/set-plan to an invalid one should fail' do
    set_dummy_secrets_to(LocationServer.all)
    prepare_default_ports

    assert_scripted do
      begin_ssh
      post '/instances/testsite/set-plan?location_str_id=canada',
           as: :json,
           params: { plan: '100000-MB' },
           headers: default_headers_auth

      assert_response :bad_request
    end
  end

  test '/instances/:instance_id/set-plan forbidden' do
    w, = prepare_forbidden_test(Website::PERMISSION_DNS)

    post "/instances/#{w.site_name}/set-plan?location_str_id=usa",
         as: :json,
         params: { plan: '100000-MB' },
         headers: default_headers_auth

    assert_response :forbidden
  end

  # DELETE /sitename
  test 'DEL /instances/:instance_id/' do
    dep_method = prepare_default_execution_method
    set_dummy_secrets_to(LocationServer.all)
    prepare_default_ports

    website = default_website
    website_location = default_website_location

    expect_global_container(dep_method)
    prepare_ssh_session(dep_method.kill_global_container(id: 'b3621dd9d4dd'),
                        'killed b3621dd9d4dd')
    prepare_ssh_session(dep_method.kill_global_container(id: '32bfe26a2712'),
                        'killed 32bfe26a2712')
    prepare_ssh_session(dep_method.clear_repository(website: website), '')

    assert_scripted do
      begin_ssh

      website_id = website.id
      website_location_id = website_location.id

      delete '/instances/testsite/?location_str_id=canada',
             as: :json,
             headers: default_headers_auth

      assert_response :success

      assert_nil Website.find_by(id: website_id)
      assert_nil WebsiteLocation.find_by(id: website_location_id)
    end
  end

  # PATCH /sitename
  test 'patch /instances/:instance_id/' do
    website = default_website
    website.crontab = ""
    website.save!

    new_crontab = "\n * * * * * ls -la\n"

    patch '/instances/testsite/',
          as: :json,
          params: {
            website: {
              crontab: new_crontab
            }
          },
          headers: default_headers_auth

    assert_response :success

    website.reload
    assert_equal website.crontab, new_crontab
  end

  test 'DEL /instances/:instance_id/ forbidden' do
    w, = prepare_forbidden_test(Website::PERMISSION_PLAN)

    delete "/instances/#{w.site_name}/?location_str_id=usa",
           as: :json,
           headers: default_headers_auth

    assert_response :forbidden
  end
end
