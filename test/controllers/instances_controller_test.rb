
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
    u = User.find_by token: '1234s56789'
    u.updated_at = Time.zone.now - 2.hours
    u.save!

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

    assert Time.zone.now - u.reload.updated_at < 10
  end

  test '/instances/ passed request ip' do
    u = User.find_by token: '1234s56789'
    u.updated_at = Time.zone.now - 2.hours
    u.save!

    get '/instances/', as: :json, headers: {
      "x-auth-token": u.token,
      "x-origin-request-ip": "127.0.0.2"
    }

    assert_response :success

    assert Time.zone.now - u.reload.updated_at < 10
    assert_equal u.latest_request_ip, "127.0.0.2"
  end

  test '/instances/ passed request ip - none already set' do
    u = User.find_by token: '1234s56789'
    u.updated_at = Time.zone.now
    u.latest_request_ip = ""
    u.save!

    get '/instances/', as: :json, headers: {
      "x-auth-token": u.token,
      "x-origin-request-ip": "127.0.0.2"
    }

    assert_response :success

    assert Time.zone.now - u.reload.updated_at < 10
    assert_equal u.latest_request_ip, "127.0.0.2"
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

  test '/instances/:instance_id with site name starting with existing website id (diff)' do
    w = default_website
    w2 = Website.all.find { |ww| ww.id != w.id && ww.user_id != w.user_id }

    w.site_name = "#{w2.id}#{w.site_name}"
    w.save!

    get "/instances/#{w.site_name}",
        as: :json,
        headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['id'], w.id
  end

  test '/instances/:instance_id with id instead of site name' do
    w = default_website

    get "/instances/#{w.id}", as: :json, headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['site_name'], 'testsite'
    assert_equal response.parsed_body['status'], 'online'
  end

  test '/instances/:instance_id by super admin should be able to access other websites' do
    Collaborator.all.each(&:destroy)
    u = default_user
    u.is_admin = true
    u.save!

    website_to_access = Website.where.not(user: u).first

    get "/instances/#{website_to_access.id}",
        as: :json,
        headers: headers_auth(u.token)

    assert_response :success
    assert_equal response.parsed_body['site_name'], website_to_access.site_name
  end

  test '/instances/summary happy path' do
    website = Website.find_by site_name: 'testsite'
    website.type = "kubernetes"
    website.storage_areas = ['/opt/app/data/']
    website.save(validate: false)

    get '/instances/summary?with=last_deployment',
        as: :json,
        headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 3

    site_to_check = response.parsed_body.find { |w| w['site_name'] == website.site_name }
    assert_equal site_to_check['site_name'], 'testsite'
    assert_equal site_to_check['hostname'], 'testsite.openode.io'
    assert_equal site_to_check['ip'], '127.0.0.1'
    assert_equal site_to_check['location']['full_name'], 'Montreal (Canada)'
    assert_equal site_to_check['price'], '1.50'
    assert_equal site_to_check['plan_name'], '100 MB'
    assert_equal site_to_check['nb_collaborators'], website.collaborators.count
    assert_equal site_to_check['last_deployment_id'], website.deployments.last.id
    assert_equal site_to_check['active'], true
    assert_equal site_to_check['persistence']['extra_storage'], 1
    assert_equal site_to_check['persistence']['storage_areas'], ['/opt/app/data/']
    assert_nil site_to_check['env']
    assert_nil site_to_check['events']
    assert_equal site_to_check['out_of_memory_detected'], false

    assert site_to_check['last_deployment']
  end

  test '/instances/summary - skip 2' do
    website = Website.find_by site_name: 'testsite'
    website.storage_areas = ['/opt/app/data/']
    website.save!
    get '/instances/summary?with=last_deployment&skip=2',
        as: :json,
        headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body[0]['site_name'], 'testkubernetes-type'
  end

  test '/instances/summary happy path with limit 1' do
    website = Website.find_by site_name: 'testsite'
    website.storage_areas = ['/opt/app/data/']
    website.save!
    get '/instances/summary?with=last_deployment&limit=1',
        as: :json,
        headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 1
  end

  test '/instances/summary using search' do
    website = Website.find_by site_name: 'testsite'
    website.type = "kubernetes"
    website.save!
    website.storage_areas = ['/opt/app/data/']
    website.save!
    get '/instances/summary?with=last_deployment&search=stsit',
        as: :json,
        headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body.first['site_name'], 'testsite'
  end

  test '/instances/summary happy path - with env' do
    website = default_website
    website.overwrite_env_variables!(TEST: 1234)

    get '/instances/summary?with=env', as: :json, headers: default_headers_auth

    assert_response :success

    site_to_check = response.parsed_body.find { |w| w['site_name'] == website.site_name }

    assert_equal site_to_check['site_name'], 'testsite'
    assert_equal site_to_check['env']['TEST'], 1234
  end

  test '/instances/summary happy path - with collaborators' do
    website = default_website
    website.type = "kubernetes"
    website.save!
    collaborators = website.collaborators
    website.overwrite_env_variables!(TEST: 1234)

    get '/instances/summary?with=collaborators',
        as: :json,
        headers: default_headers_auth

    assert_response :success

    site_to_check = response.parsed_body.find { |w| w['site_name'] == website.site_name }

    assert_equal site_to_check['site_name'], 'testsite'
    assert_equal site_to_check['collaborators'].count, collaborators.count
    assert_equal site_to_check['collaborators'].first.dig('user', 'email'),
                 'myadmin@thisisit.com'
  end

  test '/instances/summary happy path - with events' do
    website = default_website
    website.create_event(what: 'is')

    get '/instances/summary?with=events',
        as: :json,
        headers: default_headers_auth

    assert_response :success

    site_to_check = response.parsed_body.find { |w| w['site_name'] == website.site_name }

    assert_equal site_to_check['site_name'], 'testsite'
    assert_equal site_to_check['events'].count, 1
    assert_equal site_to_check['events'].first.dig('obj', 'what'), 'is'
  end

  test '/instances/summary happy path, without persistence and offline' do
    website = Website.find_by site_name: 'testsite'
    website.type = "kubernetes"
    website.save!
    wl = website.website_locations.first
    wl.extra_storage = 0
    wl.save!

    website.change_status!(Website::STATUS_OFFLINE)

    get '/instances/summary', as: :json, headers: default_headers_auth

    assert_response :success

    site_to_check = response.parsed_body.find { |w| w['site_name'] == website.site_name }
    assert_equal site_to_check['site_name'], 'testsite'
    assert_equal site_to_check['ip'], '127.0.0.1'
    assert_equal site_to_check['location']['full_name'], 'Montreal (Canada)'
    assert_equal site_to_check['price'], '1.50'
    assert_equal site_to_check['plan_name'], '100 MB'
    assert_equal site_to_check['nb_collaborators'], website.collaborators.count
    assert_equal site_to_check['last_deployment_id'], website.deployments.last.id
    assert_equal site_to_check['active'], false
    assert_equal site_to_check['persistence'].present?, false
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

  test '/instances/:id/summary happy path' do
    website = Website.find_by site_name: 'testsite'

    get "/instances/#{website.id}/summary?with=last_deployment",
        as: :json,
        headers: default_headers_auth

    assert_response :success

    site_to_check = response.parsed_body
    assert_equal site_to_check['site_name'], 'testsite'

    assert site_to_check['last_deployment']
  end

  test '/instances/status happy path' do
    website = default_website
    WebsiteStatus.create!(
      website: website,
      obj: JSON.parse(IO.read('test/fixtures/kubernetes/status.json'))
    )

    get "/instances/#{website.id}/status", as: :json, headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body.count, 1
    assert_equal response.parsed_body.first['label_app'], 'www'

    container_statuses = response.parsed_body.first.dig('status', 'containerStatuses')
    assert_equal container_statuses.first['ready'], true
  end

  test '/instances/routes happy path' do
    website = default_website
    website.type = "kubernetes"
    website.save!
    wl = website.website_locations.first
    wl.obj = { "services" => { "apiVersion" => "v1",
                               "items" => [{ "apiVersion" => "v1", "kind" => "Service",
                                             "metadata" => {
                                               "name" => "main-service"
                                             },
                                             "spec" => {
                                               "clusterIP" => "10.245.26.165",
                                               "externalTrafficPolicy" => "Cluster"
                                             } }] } }
    wl.save!

    get "/instances/#{website.id}/routes", as: :json, headers: default_headers_auth

    assert_response :success

    website_custom_domain = Website.find_by site_name: 'testprivatecloud'

    result = response.parsed_body

    assert_equal result[website.site_name]['host'], '10.245.26.165'
    assert_equal result[website.site_name]['type'], 'private_ip'
    assert_equal result[website.site_name]['protocol'], 'http'

    w_location = website.website_locations.first.location
    assert_not_equal website_custom_domain.website_locations.first.location, w_location

    main_domain_custom = website_custom_domain.website_locations.first.main_domain
    assert_equal result[website_custom_domain.site_name]['host'], main_domain_custom
    assert_equal result[website_custom_domain.site_name]['type'], 'hostname'
    assert_equal result[website_custom_domain.site_name]['protocol'], 'https'
  end

  test '/instances/status without recorded status' do
    website = default_website

    get "/instances/#{website.id}/status", as: :json, headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body.count, 0
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

  test '/instances/create with id instead of internal id' do
    post '/instances/create',
         params: { site_name: 'helloworld123', account_type: 'grun-128' },
         as: :json,
         headers: default_headers_auth

    assert_response :success

    website = Website.find(response.parsed_body['id'])

    assert_equal website.id, response.parsed_body['id']
    assert_equal website.site_name, 'helloworld123'
    assert_equal website.domain_type, 'subdomain'
    assert_equal website.account_type, Website::DEFAULT_ACCOUNT_TYPE
  end

  test '/instances/create without account type should be allowed' do
    post '/instances/create',
         params: { site_name: 'helloworld123' },
         as: :json,
         headers: default_headers_auth

    assert_response :success

    website = Website.find(response.parsed_body['id'])

    assert_equal website.id, response.parsed_body['id']
    assert_equal website.site_name, 'helloworld123'
    assert_equal website.domain_type, 'subdomain'
    assert_equal website.account_type, Website::DEFAULT_ACCOUNT_TYPE
  end

  test '/instances/create with open source' do
    post '/instances/create',
         params: {
           site_name: 'helloworld123',
           account_type: 'open_source',
           open_source_title: 'helloworld',
           open_source_description: 'asdf ' * 50,
           open_source_repository: 'http://github.com/openode-io/openode-cli'
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
    assert_equal website.open_source['repository_url'],
                 'http://github.com/openode-io/openode-cli'
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

    assert_response :success
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

  test '/instances/:instance_id/changes skip if referenced image' do
    website = default_website
    set_reference_image_website(website, Website.last)

    post '/instances/testsite/changes?location_str_id=canada',
         params: { files: '[{"path":"test/what.txt","type":"F","checksum":"123456"}]' },
         as: :json,
         headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body.length, 0
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

  # scm-clone
  test '/instances/:instance_id/scm-clone' do
    set_dummy_secrets_to(LocationServer.all)

    website = Website.find_by site_name: 'testsite'

    prepare_ssh_session("rm -rf #{website.repo_dir}", '123456789')
    prepare_ssh_session("git clone https://github.com/repo #{website.repo_dir}", '123456789')
    prepare_ssh_session("true", '123456789')
    prepare_ssh_session("cd #{website.repo_dir} ; openode template", '')

    assert_scripted do
      begin_ssh
      post '/instances/testsite/scm-clone?location_str_id=canada',
           params: { repository_url: "https://github.com/repo" },
           headers: default_headers_auth

      assert_response :success
      assert_equal response.parsed_body['status'], 'success'
    end
  end

  test '/instances/:instance_id/scm-clone sanitized' do
    set_dummy_secrets_to(LocationServer.all)

    website = Website.find_by site_name: 'testsite'

    prepare_ssh_session("rm -rf #{website.repo_dir}", '123456789')
    prepare_ssh_session("git clone \\\; ls #{website.repo_dir}", '123456789')
    prepare_ssh_session("true", '123456789')
    prepare_ssh_session("cd #{website.repo_dir} ; openode template", '')

    assert_scripted do
      begin_ssh
      post '/instances/testsite/scm-clone?location_str_id=canada',
           params: { repository_url: "; ls" },
           headers: default_headers_auth

      assert_response :success
      assert_equal response.parsed_body['status'], 'success'
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

  test '/instances/:instance_id/logs offline, without deployment' do
    set_dummy_secrets_to(LocationServer.all)
    w = default_website
    w.status = Website::STATUS_OFFLINE
    w.save!

    w.deployments.each(&:destroy)

    get "/instances/#{w.id}/logs?location_str_id=canada",
        as: :json,
        headers: default_headers_auth

    assert_response :success

    assert_includes response.parsed_body['logs'], 'No deployment logs available'
  end

  test '/instances/:instance_id/logs offline, with deployment' do
    set_dummy_secrets_to(LocationServer.all)
    w = default_website
    w.status = Website::STATUS_OFFLINE
    w.save!

    dep = Deployment.new

    dep.status = 'success'
    dep.website = w
    dep.website_location = w.website_locations.last
    dep.result = {
      what: {
        is: 2
      }
    }
    dep.events = [
      { "status": "running", "level": "info", "update": "Verifying allowed to deploy..." },
      { "status": "running", "level": "info", "update": "Preparing instance image..." }
    ]
    dep.save!

    get "/instances/#{w.id}/logs?location_str_id=canada",
        as: :json,
        headers: default_headers_auth

    assert_response :success

    assert_includes response.parsed_body['logs'], 'printing latest deployment'
    assert_includes response.parsed_body['logs'], 'Verifying allowed'
  end

  # /cmd with docker compose

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
    clear_all_queued_jobs
    dep_method = prepare_default_execution_method
    set_dummy_secrets_to(LocationServer.all)
    prepare_default_ports
    website = default_website
    website.executions.each(&:destroy)

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

      invoke_all_jobs

      assert_equal website.executions.reload.last.type, 'Task'
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
    assert_equal response.parsed_body['name'], '100MB Memory (On Demand)'
  end

  # /plans
  test '/instances/:instance_id/plans cloud' do
    get '/instances/testsite/plans?location_str_id=canada',
        as: :json,
        headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body.length, 7
    assert_equal response.parsed_body[0]['id'], 'open-source'
  end

  test '/instances/:instance_id/plans kubernetes - with subscription' do
    w = default_website
    w.type = Website::TYPE_KUBERNETES
    w.save!

    Subscription.create!(user_id: w.user.id, quantity: 1, active: true)

    get "/instances/#{w.site_name}/plans?location_str_id=canada",
        as: :json,
        headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 8
    assert_equal response.parsed_body[0]['id'], 'open-source'
    assert(response.parsed_body.find { |p| p['internal_id'] == "auto" })
  end

  test '/instances/:instance_id/plans kubernetes - without subscription' do
    w = default_website
    w.type = Website::TYPE_KUBERNETES
    w.save!

    Subscription.create!(user_id: w.user.id, quantity: 1, active: false)

    get "/instances/#{w.site_name}/plans?location_str_id=canada",
        as: :json,
        headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 7
    assert_equal response.parsed_body[0]['id'], 'open-source'
    assert_nil(response.parsed_body.find { |p| p['internal_id'] == "auto" })
  end

  # /set-plan
  test '/instances/:instance_id/set-plan to a new one' do
    set_dummy_secrets_to(LocationServer.all)
    prepare_default_ports

    website = default_website
    website.status = Website::STATUS_OFFLINE
    website.save!

    post '/instances/testsite/set-plan', # works without location str id
         as: :json,
         params: { plan: '200-MB' },
         headers: default_headers_auth

    assert_response :success

    website.reload
    assert_equal website.account_type, 'third'
    assert_equal website.cloud_type, 'cloud'

    event = website.events.first
    assert_equal event.obj['original_value'], "100-MB"
    assert_equal event.obj['new_value'], "200-MB"
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
    w, = prepare_forbidden_test(Website::PERMISSION_LOCATION)

    post "/instances/#{w.site_name}/set-plan?location_str_id=usa",
         as: :json,
         params: { plan: '100000-MB' },
         headers: default_headers_auth

    assert_response :forbidden
  end

  # DELETE /sitename
  test 'DEL /instances/:instance_id/ - happy path' do
    set_dummy_secrets_to(LocationServer.all)
    prepare_default_ports

    website = default_website
    website.change_status!(Website::STATUS_OFFLINE)
    website_location = default_website_location
    website_location.extra_storage = 0
    website_location.save!

    assert_not website.active?

    website_id = website.id
    website_location_id = website_location.id

    delete "/instances/#{website.id}/?location_str_id=canada",
           as: :json,
           headers: default_headers_auth

    assert_response :success

    assert_nil Website.find_by(id: website_id)
    assert_nil WebsiteLocation.find_by(id: website_location_id)
  end

  test 'DEL /instances/:instance_id/ - fail if online' do
    website = default_website
    website.change_status!(Website::STATUS_ONLINE)
    website_location = default_website_location

    website_id = website.id
    website_location_id = website_location.id

    delete "/instances/#{website.id}/?location_str_id=canada",
           as: :json,
           headers: default_headers_auth

    assert_response :bad_request

    assert Website.find_by(id: website_id)
    assert WebsiteLocation.find_by(id: website_location_id)
  end

  # PATCH /sitename
  test 'patch /instances/:instance_id/' do
    website = default_website
    website.save!

    patch '/instances/testsite/',
          as: :json,
          params: {
            website: {
              alerts: [Website::ALERT_STOP_LACK_CREDITS]
            }
          },
          headers: default_headers_auth

    assert_response :success

    website.reload
    assert_equal website.alerts, [Website::ALERT_STOP_LACK_CREDITS]
  end

  test 'patch /instances/:instance_id/ change to custom domain' do
    website = default_website

    patch '/instances/testsite/',
          as: :json,
          params: {
            website: {
              site_name: "www.mydomainname.com"
            }
          },
          headers: default_headers_auth

    assert_response :success

    website.reload
    assert_equal website.site_name, "www.mydomainname.com"
    assert_equal website.domain_type, "custom_domain"
  end

  test 'DEL /instances/:instance_id/ forbidden' do
    w, = prepare_forbidden_test(Website::PERMISSION_PLAN)

    delete "/instances/#{w.site_name}/?location_str_id=usa",
           as: :json,
           headers: default_headers_auth

    assert_response :forbidden
  end

  test 'post /instances/:instance_id/prepare-one-click-app happy path' do
    website = default_website
    website.change_status!(Website::STATUS_OFFLINE)
    app = OneClickApp.last
    wl = website.website_locations.first.reload
    wl.extra_storage = 0
    wl.save!

    app.prepare = """
    wl = @website.website_locations.first

    unless wl.extra_storage.positive?
      wl.extra_storage += 1
      wl.save
    end
    """

    app.save!

    post "/instances/#{website.id}/prepare-one-click-app",
         as: :json,
         params: { one_click_app_id: app.id.to_s },
         headers: default_headers_auth

    assert_response :success

    wl.reload

    assert_equal wl.extra_storage, 1
  end

  test 'post /instances/:instance_id/prepare-one-click-app with invalid one click app' do
    website = default_website
    website.change_status!(Website::STATUS_OFFLINE)
    app = OneClickApp.last
    wl = website.website_locations.first.reload
    wl.extra_storage = 0
    wl.save!

    app.prepare = """
    wl = @website.website_locations.first

    unless wl.extra_storage.positive?
      wl.extra_storage += 1
      wl.save
    end
    """

    app.save!

    post "/instances/#{website.id}/prepare-one-click-app",
         as: :json,
         params: { one_click_app_id: "invalid" },
         headers: default_headers_auth

    assert_response :not_found
  end

  test 'patch /instances/:instance_id/one-click-app happy path' do
    website = default_website
    website.change_status!(Website::STATUS_OFFLINE)
    website.one_click_app = { "test" => "22" }
    website.save!

    patch "/instances/#{website.id}/one-click-app",
          as: :json,
          params: { attributes: { "version" => "latest" } },
          headers: default_headers_auth

    assert_response :success

    website.reload

    assert_equal website.one_click_app, { "version" => "latest", "test" => "22" }
  end
end
