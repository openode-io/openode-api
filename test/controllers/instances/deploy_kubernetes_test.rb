
require 'test_helper'
require 'test_kubernetes_helper'

class InstancesControllerDeployKubernetesTest < ActionDispatch::IntegrationTest
  def setup
    @website = default_kube_website
    @website_location = @website.website_locations.first

    prepare_kubernetes_method(@website, @website_location)
    clear_all_queued_jobs
  end

  def prepare_kubernetes_method(website, website_location)
    runner = prepare_kubernetes_runner(website, website_location)

    @kubernetes_method = runner.get_execution_method
  end

  def prepare_launch_happy_path(kubernetes_method, website, website_location,
                                parent_deployment = nil)
    prepare_make_namespace(kubernetes_method, website, website_location, "result")
    prepare_make_secret(kubernetes_method, website, website_location, "result")

    deployment = website.deployments.last

    if !parent_deployment && website.reference_website_image.blank?
      prepare_check_repo_size(kubernetes_method, website, "1231 /what")
      prepare_build_image(kubernetes_method, website, deployment, "new image built")
      prepare_push_image(kubernetes_method, website, deployment, "result")
    end

    prepare_action_yml(kubernetes_method, website_location, "apply.yml",
                       "apply -f apply.yml", 'success')

    get_pods_json_content = IO.read('test/fixtures/kubernetes/1_pod_alive.json')
    prepare_get_pods_json(kubernetes_method, website, website_location, get_pods_json_content,
                          0)

    prepare_instance_up(kubernetes_method, website, website_location, 'success', 0)

    get_pods_json_content = IO.read('test/fixtures/kubernetes/1_pod_alive.json')
    prepare_get_pods_json(kubernetes_method, website, website_location, get_pods_json_content,
                          0)
    prepare_kubernetes_logs(kubernetes_method, "hello logs", 0,
                            website: website,
                            website_location: website_location,
                            nb_lines: 1_000)

    prepare_get_services_json(kubernetes_method, website, website_location,
                              IO.read('test/fixtures/kubernetes/get_services.json'))
  end

  test '/instances/:instance_id/restart - happy path' do
    @website.save!

    website2 = Website.where.not(id: @website.id).first

    assert_not_equal website2.id, @website.id

    ws1 = WebsiteStatus.log(@website, test: 234)
    ws2 = WebsiteStatus.log(website2, test: 234)

    post "/instances/#{@website.site_name}/restart",
         as: :json,
         params: base_params,
         headers: default_headers_auth

    prepare_launch_happy_path(@kubernetes_method, @website, @website_location)

    assert_nil WebsiteStatus.find_by(id: ws1.id)
    assert WebsiteStatus.find_by(id: ws2.id)

    assert_scripted do
      begin_ssh
      invoke_all_jobs

      deployment = @website.deployments.last
      @website.reload

      assert_equal @website.status, Website::STATUS_ONLINE
      assert_equal deployment.status, Deployment::STATUS_SUCCESS
      assert_equal deployment.result['steps'].length, 17 # global, 2 kills, finalize

      assert_equal deployment.result['errors'].length, 0

      # should also have a deployment with events
      assert_equal deployment.events.length, 15

      allowed_to = dep_event_exists?(deployment.events,
                                     'running', 'allowed to dep')
      assert_equal allowed_to, true

      assert deployment.obj['image_name_tag'].present?
      assert_includes deployment.obj['image_name_tag'],
                      'docker.io/openode_prod/testkubernetes-type:testkubernetes-type'

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
        { "status" => "success", "level" => "info", "update" => "hello logs" },
        { "status" => "success", "level" => "info",
          "update" => "\n\n*** Final Deployment state: SUCCESS ***\n" },
        { "status" => "success", "level" => "info", "update" => "...finalized." }
      ]

      steps_to_verify.each do |step|
        Rails.logger.info "checking step .. #{step.inspect}"
        verified_event = dep_event_exists?(deployment.events,
                                           step['status'], step['update'])
        assert_equal verified_event, true
      end

      final_details_event = @website.deployments.last.events.find do |e|
        e.dig('update', 'details', 'result') rescue nil
      end

      assert_not_nil final_details_event
      assert_equal(final_details_event['update']['details']['url'],
                   "http://#{@website.site_name}.#{CloudProvider::Manager.base_hostname}/")
    end
  end

  test '/instances/:instance_id/restart - happy path with repository url (public)' do
    @website.save!

    website2 = Website.where.not(id: @website.id).first

    assert_not_equal website2.id, @website.id

    ws1 = WebsiteStatus.log(@website, test: 234)
    ws2 = WebsiteStatus.log(website2, test: 234)

    repository_url = "git@myrepo.com/thisone;"

    post "/instances/#{@website.site_name}/restart",
         as: :json,
         params: base_params.merge(repository_url: repository_url),
         headers: default_headers_auth

    prepare_launch_happy_path(@kubernetes_method, @website, @website_location)

    assert_nil WebsiteStatus.find_by(id: ws1.id)
    assert WebsiteStatus.find_by(id: ws2.id)

    assert_equal @website.secret[:repository_url], "git@myrepo.com/thisone\\;"

    assert_scripted do
      begin_ssh
      invoke_all_jobs

      deployment = @website.deployments.last

      assert_equal deployment.obj['with_repository_url'], "git@myrepo.com/thisone\\;"

      @website.reload

      assert_equal @website.status, Website::STATUS_ONLINE
      assert_equal deployment.status, Deployment::STATUS_SUCCESS
      assert_equal deployment.result['steps'].length, 17 # global, 2 kills, finalize

      assert_equal deployment.result['errors'].length, 0

      # should also have a deployment with events
      assert_equal deployment.events.length, 15

      allowed_to = dep_event_exists?(deployment.events,
                                     'running', 'allowed to dep')
      assert_equal allowed_to, true

      assert deployment.obj['image_name_tag'].present?
      assert_includes deployment.obj['image_name_tag'],
                      'docker.io/openode_prod/testkubernetes-type:testkubernetes-type'

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
        { "status" => "success", "level" => "info", "update" => "hello logs" },
        { "status" => "success", "level" => "info",
          "update" => "\n\n*** Final Deployment state: SUCCESS ***\n" },
        { "status" => "success", "level" => "info", "update" => "...finalized." }
      ]

      steps_to_verify.each do |step|
        Rails.logger.info "checking step .. #{step.inspect}"
        verified_event = dep_event_exists?(deployment.events,
                                           step['status'], step['update'])
        assert_equal verified_event, true
      end

      final_details_event = @website.deployments.last.events.find do |e|
        if e.instance_of?(String)
          nil
        else
          e.dig('update', 'details', 'result') rescue nil
        end
      end

      assert_not_nil final_details_event
      assert_equal(final_details_event['update']['details']['url'],
                   "http://#{@website.site_name}.#{CloudProvider::Manager.base_hostname}/")
    end
  end

  test '/instances/:instance_id/restart - rollback' do
    @website.save!

    parent_deployment = @website.deployments.last
    parent_deployment.obj ||= {}
    parent_deployment.obj['image_name_tag'] = 'mypreviousimage'
    parent_deployment.save!

    post "/instances/#{@website.site_name}/restart",
         as: :json,
         params: base_params.merge(parent_execution_id: parent_deployment.id.to_s),
         headers: default_headers_auth

    prepare_launch_happy_path(@kubernetes_method, @website,
                              @website_location, parent_deployment)

    assert_scripted do
      begin_ssh
      invoke_all_jobs

      deployment = @website.deployments.last
      @website.reload

      assert_equal @website.status, Website::STATUS_ONLINE
      assert_equal deployment.status, Deployment::STATUS_SUCCESS

      assert_equal deployment.parent_execution.id, parent_deployment.id
      assert_equal deployment.obj['image_name_tag'],
                   parent_deployment.obj['image_name_tag']
    end
  end

  test '/instances/:instance_id/restart - with reference_website_image' do
    @website.save!

    referenced_website = Website.last

    img_name_tag = 'mypretty/image'

    Deployment.create!(
      website: referenced_website,
      website_location: referenced_website.website_locations.first,
      status: Deployment::STATUS_RUNNING,
      obj: {
        image_name_tag: img_name_tag
      }
    )

    set_reference_image_website(@website, referenced_website)

    post "/instances/#{@website.site_name}/restart",
         as: :json,
         params: base_params,
         headers: default_headers_auth

    prepare_launch_happy_path(@kubernetes_method, @website,
                              @website_location)

    assert_scripted do
      begin_ssh
      invoke_all_jobs

      deployment = @website.deployments.last
      @website.reload

      assert_equal @website.status, Website::STATUS_ONLINE
      assert_equal deployment.status, Deployment::STATUS_SUCCESS

      assert_equal deployment.obj['image_name_tag'], img_name_tag
    end
  end

  # stop with kubernetes
  test '/instances/:instance_id/stop ' do
    @website.one_click_app = { id: 123 }
    @website.save!
    prepare_make_secret(@kubernetes_method, @website, @website_location, "result")

    prepare_action_yml(@kubernetes_method, @website_location, "apply.yml",
                       "delete --timeout 30s  -f apply.yml", 'success')

    current_time = Time.zone.now
    travel_to current_time.beginning_of_hour + 30.minutes
    @website.deployments.destroy_all

    assert_scripted do
      begin_ssh
      post "/instances/#{@website.site_name}/stop?location_str_id=canada",
           as: :json,
           params: {},
           headers: default_headers_auth

      assert_response :success
      assert_equal response.parsed_body['result'], 'success'

      invoke_all_jobs

      @website.reload

      assert_equal @website.status, Website::STATUS_OFFLINE
      assert_equal @website.executions.last.type, 'Task'
      assert_equal @website.one_click_app, { "id" => 123 }

      last_credit_action = @website.credit_actions.reload.last
      expected_ratio = 0.4950

      assert_in_delta @website.plan[:cost_per_hour] * 100.0 * expected_ratio,
                      last_credit_action.credits_spent, 0.0001
    end
  end

  test '/instances/:instance_id/stop - with subscription' do
    # with auto
    @website.account_type = Website::AUTO_ACCOUNT_TYPE
    @website.save!

    s = Subscription.create!(active: true, user: @website.user, quantity: 2)
    SubscriptionWebsite.create!(website: @website, subscription: s, quantity: 1)

    prepare_make_secret(@kubernetes_method, @website, @website_location, "result")

    prepare_action_yml(@kubernetes_method, @website_location, "apply.yml",
                       "delete --timeout 30s  -f apply.yml", 'success')

    current_time = Time.zone.now
    travel_to current_time.beginning_of_hour + 30.minutes
    @website.deployments.destroy_all

    assert_scripted do
      begin_ssh
      post "/instances/#{@website.site_name}/stop?location_str_id=canada",
           as: :json,
           params: {},
           headers: default_headers_auth

      assert_response :success
      assert_equal response.parsed_body['result'], 'success'

      invoke_all_jobs

      @website.reload

      assert_equal @website.status, Website::STATUS_OFFLINE
      assert_equal @website.executions.last.type, 'Task'

      last_credit_action = @website.credit_actions.reload.last
      expected_ratio = 0

      assert_in_delta @website.plan[:cost_per_hour] * 100.0 * expected_ratio,
                      last_credit_action.credits_spent, 0.0001

      subscription_website = SubscriptionWebsite.find_by(website: @website)

      assert_nil subscription_website
    end
  end

  test '/instances/:instance_id/stop - if kube stop fail, should put back to online' do
    prepare_make_secret(@kubernetes_method, @website, @website_location, "result")

    prepare_action_yml(@kubernetes_method, @website_location, "apply.yml",
                       "delete --timeout 30s  -f apply.yml", 'success', 1)

    assert_scripted do
      begin_ssh
      post "/instances/#{@website.site_name}/stop?location_str_id=canada",
           as: :json,
           params: {},
           headers: default_headers_auth

      assert_response :success
      assert_equal response.parsed_body['result'], 'success'

      invoke_all_jobs

      @website.reload

      assert_equal @website.status, Website::STATUS_OFFLINE
    end
  end

  test '/instances/:instance_id/stop - should still stop if site is invalid' do
    @website.update_attribute('account_type', 'open_source')
    @website.update_attribute('open_source',
                              'status' => 'approved',
                              'title' => 'helloworld',
                              'description' => 'a ' * 31,
                              'repository_url' => 'http://github.com/invalid')

    prepare_make_secret(@kubernetes_method, @website, @website_location, "result")

    prepare_action_yml(@kubernetes_method, @website_location, "apply.yml",
                       "delete --timeout 30s  -f apply.yml", 'success')

    assert_scripted do
      begin_ssh
      post "/instances/#{@website.site_name}/stop?location_str_id=canada",
           as: :json,
           params: {},
           headers: default_headers_auth

      assert_response :success
      assert_equal response.parsed_body['result'], 'success'

      invoke_all_jobs

      @website.reload

      assert_equal @website.reload.status, Website::STATUS_OFFLINE
    end
  end

  test '/instances/:instance_id/reload - with last deployment' do
    parent_deployment = @website.deployments.last
    parent_deployment.obj ||= {}
    parent_deployment.obj['image_name_tag'] = 'mypreviousimage'
    parent_deployment.save!

    prepare_make_secret(@kubernetes_method, @website, @website_location, "result")
    prepare_action_yml(@kubernetes_method, @website_location, "apply.yml",
                       "apply -f apply.yml", 'success')

    assert_scripted do
      begin_ssh
      post "/instances/#{default_kube_website.site_name}/reload?location_str_id=canada",
           as: :json,
           params: {},
           headers: default_headers_auth

      deployment = @website.deployments.last

      assert_response :success
      assert_equal response.parsed_body['result'], 'success'
      assert_equal response.parsed_body['deploymentId'], deployment.id
      assert_equal response.parsed_body.dig('website', 'site_name'), default_kube_website.site_name

      invoke_all_jobs

      deployment.reload

      assert_not_equal deployment, parent_deployment
      assert_equal deployment.status, Execution::STATUS_SUCCESS
      assert_equal deployment.obj['image_name_tag'], 'mypreviousimage'
    end
  end

  test '/instances/:instance_id/reload - without latest image' do
    prepare_make_secret(@kubernetes_method, @website, @website_location, "result")

    assert_scripted do
      begin_ssh
      post "/instances/#{default_kube_website.site_name}/reload?location_str_id=canada",
           as: :json,
           params: {},
           headers: default_headers_auth

      deployment = @website.deployments.last

      assert_response :success
      assert_equal response.parsed_body['result'], 'success'
      assert_equal response.parsed_body['deploymentId'], deployment.id

      invoke_all_jobs

      deployment.reload

      assert_equal deployment.status, Execution::STATUS_FAILED
      assert_includes deployment.events.first['update'], 'Missing instance image'
    end
  end
end
