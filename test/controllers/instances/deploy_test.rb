
require 'test_helper'

class InstancesControllerDeployTest < ActionDispatch::IntegrationTest

  def run_deployer_job()
    job = Delayed::Job.where("handler LIKE ?", "%#{"DeploymentMethod::Deployer"}%").first

    job.invoke_job
  end
  
  test "/instances/:instance_id/restart requires minimum CLI version" do
    post "/instances/testsite/restart", as: :json, headers: default_headers_auth

    assert_response :bad_request
    assert_includes response.parsed_body["error"], "Deprecated"
  end

  test "/instances/:instance_id/restart should not be starting" do
  	website = Website.find_by! site_name: "testsite"
    website.change_status!(Website::STATUS_STARTING)

    post "/instances/testsite/restart?version=#{InstancesController::MINIMUM_CLI_VERSION}", 
    	as: :json, 
    	headers: default_headers_auth

    assert_response :bad_request
    assert_includes response.parsed_body["error"], "The instance must be in status"
  end

  test "/instances/:instance_id/restart should not allow when no credit" do
    dep_method = prepare_default_deployment_method

    website = default_website
    website.user.credits = 0
    website.user.save

    prepare_default_ports
    
    post "/instances/testsite/restart",
      as: :json,
      params: base_params,
      headers: default_headers_auth

    assert_response :success

    prepare_default_kill_all(dep_method)

    assert_scripted do
      begin_ssh
      run_deployer_job
      
      deployment = website.deployments.last
      website.reload

      assert_equal website.status, Website::STATUS_OFFLINE
      assert_equal deployment.status, Deployment::STATUS_FAILED
      assert_equal deployment.result["steps"].length, 4 # global, 2 kills, finalize

      assert_includes deployment.result["errors"][0]["title"], "No credit"
    end
  end

  test "/instances/:instance_id/restart should not allow when user not activated" do
    dep_method = prepare_default_deployment_method

    website = default_website
    website.user.activated = false
    website.user.save

    prepare_default_ports

    post "/instances/testsite/restart", 
      as: :json, 
      params: base_params,
      headers: default_headers_auth

    assert_response :success

    prepare_default_kill_all(dep_method)

    assert_scripted do
      begin_ssh
      run_deployer_job

      deployment = website.deployments.last
      website.reload

      assert_equal website.status, Website::STATUS_OFFLINE
      assert_equal deployment.status, Deployment::STATUS_FAILED
      assert_equal deployment.result["steps"].length, 4 # global, 2 kills, finalize

      assert_includes deployment.result["errors"][0]["title"], "User account not yet activated"
    end
  end

  test "/instances/:instance_id/restart should not allow when user suspended" do
    dep_method = prepare_default_deployment_method

    website = default_website
    website.user.suspended = true
    website.user.save

    prepare_default_ports

    post "/instances/testsite/restart", 
      as: :json, 
      params: base_params,
      headers: default_headers_auth

    prepare_default_kill_all(dep_method)

    assert_scripted do
      begin_ssh
      run_deployer_job

      deployment = website.deployments.last
      website.reload

      assert_equal website.status, Website::STATUS_OFFLINE
      assert_equal deployment.status, Deployment::STATUS_FAILED
      assert_equal deployment.result["steps"].length, 4 # global, 2 kills, finalize

      assert_includes deployment.result["errors"][0]["title"], "User suspended"
    end
  end

  test "/instances/:instance_id/restart - happy path" do
    dep_method = prepare_default_deployment_method
    website = default_website
    website.crontab = ""
    website.save
    website_location = default_website_location

    prepare_default_ports
    website.reload
    website_location.reload

    post "/instances/testsite/restart", 
      as: :json, 
      params: base_params,
      headers: default_headers_auth

    prepare_get_docker_compose(dep_method, website)
    prepare_ssh_session(dep_method.prepare_dind_compose_image, "empty")
    expect_global_container(dep_method)
    prepare_ssh_session(dep_method.kill_global_container({ id: "b3621dd9d4dd" }), "killed b3621dd9d4dd")
    prepare_front_container(dep_method, website, website_location, "")
    expect_global_container(dep_method)

    prepare_docker_compose(dep_method, "b3621dd9d4dd", "")
    prepare_ssh_session(dep_method.ps( { front_container_id: "b3621dd9d4dd" }), 
      IO.read("test/fixtures/docker/docker-compose-ps.txt"))

    #prepare_ssh_session(dep_method.instance_up_cmd({ website_location: website_location }), "")
    
    expect_global_container(dep_method)
    prepare_ssh_session(dep_method.kill_global_container({ id: "32bfe26a2712" }), "killed 32bfe26a2712")

    assert_scripted do
      begin_ssh
      run_deployer_job

      deployment = website.deployments.last
      website.reload

      assert_equal website.status, Website::STATUS_ONLINE
      assert_equal deployment.status, Deployment::STATUS_SUCCESS
      assert_equal deployment.result["steps"].length, 16 # global, 2 kills, finalize

      assert_equal deployment.result["errors"].length, 0
    end
  end

end
