
require 'test_helper'
require 'test_kubernetes_helper'

class InstancesControllerDeployKubernetesTest < ActionDispatch::IntegrationTest
  def setup
    @website = default_kube_website
    @website_location = @website.website_locations.first

    prepare_kubernetes_method(@website, @website_location)
  end

  def prepare_kubernetes_method(website, website_location)
    runner = prepare_kubernetes_runner(website, website_location)

    @kubernetes_method = runner.get_execution_method
  end

  def prepare_launch_happy_path(kubernetes_method, website, website_location)
    prepare_make_secret(kubernetes_method, website, website_location, "result")
    prepare_check_repo_size(kubernetes_method, website, "1231 /what")

    deployment = website.deployments.last

    prepare_build_image(kubernetes_method, website, deployment, "new image built")
    prepare_push_image(kubernetes_method, website, deployment, "result")
    prepare_get_dotenv(kubernetes_method, website, "VAR1=12")

    prepare_get_services_default_happy(kubernetes_method, website_location)

    prepare_action_yml(kubernetes_method, website_location, "apply.yml",
                       "apply -f apply.yml", 'success')
    prepare_node_alive(kubernetes_method, website, website_location, 'success', 1)
    prepare_instance_up(kubernetes_method, website, website_location, 'success', 0)
  end

  test '/instances/:instance_id/restart - happy path' do
    @website.crontab = ''
    @website.save!

    post "/instances/#{@website.site_name}/restart",
         as: :json,
         params: base_params,
         headers: default_headers_auth

    prepare_launch_happy_path(@kubernetes_method, @website, @website_location)

    assert_scripted do
      begin_ssh
      run_deployer_job

      deployment = @website.deployments.last
      @website.reload

      assert_equal @website.status, Website::STATUS_ONLINE
      assert_equal deployment.status, Deployment::STATUS_SUCCESS
      assert_equal deployment.result['steps'].length, 14 # global, 2 kills, finalize

      assert_equal deployment.result['errors'].length, 0

      # should also have a deployment with events
      assert_equal deployment.events.length, 14

      allowed_to = dep_event_exists?(deployment.events,
                                     'running', 'allowed to dep')
      assert_equal allowed_to, true

      steps_to_verify = [
        { "status" => "running", "level" => "info", "update" => "Verifying allowed to deploy..." },
        { "status" => "running", "level" => "info", "update" => "Preparing instance image..." },
        { "status" => "running", "level" => "info", "update" => "new image built" },
        { "status" => "running", "level" => "info", "update" => "Instance image ready." },
        { "status" => "running", "level" => "info", "update" => "Pushing instance image..." },
        { "status" => "running", "level" => "info",
          "update" => "Instance image pushed successfully." },
        { "status" => "running", "level" => "info",
          "update" => "Applying instance environment..." },
        { "status" => "running", "level" => "info", "update" => "success" },
        { "status" => "running", "level" => "info", "update" => "Verifying instance up..." },
        { "status" => "running", "level" => "info",
          "update" => "...instance verification finished." },
        { "status" => "running", "level" => "info", "update" => "Finalizing..." },
        { "status" => "success", "level" => "info", "update" => "...finalized." }
      ]

      steps_to_verify.each do |step|
        Rails.logger.info "checking step .. #{step.inspect}"
        verified_event = dep_event_exists?(deployment.events,
                                           step['status'], step['update'])
        assert_equal verified_event, true
      end

      final_details_event = @website.deployments.last.events.find do |e|
        e['update'].andand['details'].andand['result']
      end

      assert_not_nil final_details_event
      assert_equal(final_details_event['update']['details']['url'],
                   "http://#{@website.site_name}.dev.#{CloudProvider::Manager.base_hostname}/")
    end
  end

  # stop with docker compose internal
  test '/instances/:instance_id/stop ' do
    prepare_make_secret(@kubernetes_method, @website, @website_location, "result")
    prepare_get_dotenv(@kubernetes_method, @website, "VAR1=12")

    prepare_get_services_default_happy(@kubernetes_method, @website_location)

    prepare_action_yml(@kubernetes_method, @website_location, "apply.yml",
                       "delete -f apply.yml", 'success')

    assert_scripted do
      begin_ssh
      post "/instances/#{@website.site_name}/stop?location_str_id=canada",
           as: :json,
           params: {},
           headers: default_headers_auth

      assert_response :success
      assert_equal response.parsed_body['result'], 'success'

      @website.reload

      assert_equal @website.status, Website::STATUS_OFFLINE
      assert_equal @website.executions.last.type, 'Task'
    end
  end
end
