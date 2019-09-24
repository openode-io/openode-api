require 'test_helper'

class InstancesControllerTest < ActionDispatch::IntegrationTest
  test "/instances/ with param token" do
    user = default_user

    get "/instances/?token=#{user.token}", as: :json

    assert_response :success
    assert_equal response.parsed_body.length, 2
    assert_equal response.parsed_body[0]["site_name"], "testsite"
    assert_equal response.parsed_body[0]["status"], "online"
  end

  test "/instances/ with header token" do
    w = Website.find_by site_name: "testsite"
    w.domains = []
    w.save
    get "/instances/", as: :json, headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body.length, 2
    assert_equal response.parsed_body[0]["site_name"], "testsite"
    assert_equal response.parsed_body[0]["status"], "online"

    assert_equal response.parsed_body[0]["domains"], []
  end

  test "/instances/ with valid API version (equal to)" do
    InstancesController::MINIMUM_CLI_VERSION = "2.0.1"
    get "/instances/?version=2.0.1", as: :json, headers: default_headers_auth

    assert_response :success
  end

  test "/instances/ with valid API version (greater than)" do
    InstancesController::MINIMUM_CLI_VERSION = "2.0.1"
    get "/instances/?version=2.2.2", as: :json, headers: default_headers_auth

    assert_response :success
  end

  test "/instances/ with deprecated api version" do
    InstancesController::MINIMUM_CLI_VERSION = "2.0.1"
    get "/instances/?version=1.0.1", as: :json, headers: default_headers_auth

    assert_response :bad_request
  end

  test "/instances/:instance_id with valid site name" do
    get "/instances/testsite", as: :json, headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body["site_name"], "testsite"
    assert_equal response.parsed_body["status"], "online"
  end

  test "/instances/:instance_id with custom domain" do
    get "/instances/www.what.is", as: :json, headers: default_headers_auth

    assert_response :success
  end

  test "/instances/:instance_id with non existent site name" do
    get "/instances/testsite10", as: :json, headers: default_headers_auth

    assert_response :not_found
  end

  # /changes
  test "/instances/:instance_id/changes with one file deleted" do
    set_dummy_secrets_to(LocationServer.all)

    website = Website.find_by site_name: "testsite"

    cmd = DeploymentMethod::DockerCompose.new.files_listing({ path: website.repo_dir })

    prepare_ssh_session(cmd, '[{"path":"test/what.txt","type":"F","checksum":"123456"},' +
      '{"path":"test/what2.txt","type":"F","checksum":"123457"}]')

    assert_scripted do
      begin_ssh
      post "/instances/testsite/changes?location_str_id=canada", 
          params: { files: '[{"path":"test/what.txt","type":"F","checksum":"123456"}]' },
          as: :json, 
          headers: default_headers_auth

      assert_response :success
      assert_equal response.parsed_body.length, 1
      assert_equal response.parsed_body[0]["path"], "test/what2.txt"
      assert_equal response.parsed_body[0]["change"], "D"
    end
  end

  # send_compressed_file
  test "/instances/:instance_id/send_compressed_file " do
    set_dummy_secrets_to(LocationServer.all)
    file_to_upload = fixture_file_upload('files/small_repo.zip')

    website = Website.find_by site_name: "testsite"

    prepare_ssh_ensure_remote_repository(website)
    prepare_send_remote_repo(website, "small_repo.zip", "all ok")

    assert_scripted do
      begin_sftp
      begin_ssh
      post "/instances/testsite/sendCompressedFile?location_str_id=canada", 
          params: { file: file_to_upload },
          headers: default_headers_auth

      assert_response :success
      assert_equal response.parsed_body["result"], "success"
    end
  end

  # /delete_files
  test "/instances/:instance_id/deleteFiles " do
    set_dummy_secrets_to(LocationServer.all)

    website = Website.find_by site_name: "testsite"

    cmd = DeploymentMethod::DockerCompose.new.delete_files({ files: [
      "#{website.repo_dir}./test.txt",
      "#{website.repo_dir}./test2.txt"
    ]})
    prepare_ssh_session(cmd, '')

    assert_scripted do
      begin_sftp
      begin_ssh

      files = [
        { "path" => "./test.txt" },
        { "path" => "./test2.txt" }
      ]

      delete "/instances/testsite/deleteFiles?location_str_id=canada", 
          params: { filesInfo: files },
          headers: default_headers_auth

      assert_response :success
      assert_equal response.parsed_body["result"], "success"
    end
  end

  # /logs with docker compose
  test "/instances/:instance_id/logs with subdomain" do
    set_dummy_secrets_to(LocationServer.all)

    prepare_ssh_session("docker exec 123456789 docker-compose logs --tail=100", "hellooutput")

    assert_scripted do
      begin_ssh
      get "/instances/testsite/logs?location_str_id=canada", as: :json, headers: default_headers_auth

      assert_response :success
      assert_equal response.parsed_body["logs"], "hellooutput"
    end
  end

  # /cmd with docker compose
  test "/instances/:instance_id/cmd with subdomain" do
    set_dummy_secrets_to(LocationServer.all)

    prepare_ssh_session("docker exec 123456789 docker-compose exec -T  www ls\\ -la", "hellooutput")

    assert_scripted do
      begin_ssh
      post "/instances/testsite/cmd?location_str_id=canada", 
        as: :json,
        params: { service: "www", cmd: "ls -la" },
        headers: default_headers_auth

      assert_response :success
      assert_equal response.parsed_body["result"]["stdout"], "hellooutput"
    end
  end

  test "/instances/:instance_id/cmd fail if offline" do
    set_dummy_secrets_to(LocationServer.all)
    website = Website.find_by! site_name: "testsite"
    website.status = Website::STATUS_OFFLINE
    website.save!

    assert_scripted do
      begin_ssh
      post "/instances/testsite/cmd?location_str_id=canada", 
        as: :json,
        params: { service: "www", cmd: "ls -la" },
        headers: default_headers_auth

      assert_response :bad_request
    end
  end

  # /erase-all with docker compose
  test "/instances/:instance_id/erase-all typical scenario" do
    set_dummy_secrets_to(LocationServer.all)

    website = Website.find_by! site_name: "testsite"
    path_repo = "#{Website::REPOS_BASE_DIR}#{website.user_id}/#{website.site_name}/"
    prepare_ssh_session("rm -rf #{path_repo}", "out1")
    prepare_ssh_session("mkdir -p #{path_repo}", "out2")

    assert_scripted do
      begin_ssh
      post "/instances/testsite/erase-all?location_str_id=canada", as: :json, headers: default_headers_auth

      assert_response :success
      assert_equal response.parsed_body["result"], "success"

      assert_equal website.events.count, 1
      assert_equal website.events[0].obj["title"], "Repository cleared (erase-all)"
    end
  end
end
