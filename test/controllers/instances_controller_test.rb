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
  test "/instances/:instance_id/changes with subdomain" do
    set_dummy_secrets_to(LocationServer.all)

    website = Website.find_by site_name: "testsite"

    cmd = DeploymentMethod::Base.new.files_listing({ path: website.repo_dir })

    prepare_ssh_session(cmd, "[]")

    assert_scripted do
      begin_ssh
      post "/instances/testsite/changes?location_str_id=canada", 
          params: { files: "[]" },
          as: :json, 
          headers: default_headers_auth

      assert_response :success
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
