
require 'test_helper'

class InstancesControllerDeployKubernetesTest < ActionDispatch::IntegrationTest
  def setup
    @website = default_kube_website
    @website_location = @website.website_locations.first

    runner = prepare_kubernetes_runner(@website, @website_location)

    @kubernetes_method = runner.get_execution_method
  end

  test '/instances/:instance_id/restart - happy path' do
    dep_method = @kubernetes_method
    @website.crontab = ''
    @website.save

    post "/instances/#{@website.site_name}/restart",
         as: :json,
         params: base_params,
         headers: default_headers_auth

    cmd_create_secret = dep_method.kubectl(
      website_location: @website_location,
      s_arguments:
        " -n instance-#{@website.id} create secret docker-registry regcred " \
        "--docker-server=https://index.docker.io/v1/ " \
        "--docker-username=test --docker-password=t123456 " \
        "--docker-email=test@openode.io "
    )

    prepare_ssh_session(cmd_create_secret, 'result-create-secret')

    prepare_ssh_session("du -bs /home/#{@website.user_id}/#{@website.site_name}/", '1231 /what')

    deployment = @website.deployments.last

    prepare_ssh_session("cd /home/#{@website.user_id}/#{@website.site_name}/ && " \
                        "docker build -t test/openode_prod:" \
                        "#{@website.site_name}--#{@website.id}--#{deployment.id} .", 'result')

    prepare_ssh_session("echo t123456 | docker login -u test --password-stdin && " \
                        "docker push test/openode_prod:" \
                        "#{@website.site_name}--#{@website.id}--#{deployment.id}", 'result')

    prepare_ssh_session("cat /home/#{@website.user_id}/#{@website.site_name}/.env", 'result')

    DeploymentMethod::Kubernetes.set_kubectl_file_path("apply.yml")

    cmd_apply = dep_method.kubectl(
      website_location: @website_location,
      s_arguments: "apply -f apply.yml"
    )
    prepare_ssh_session(cmd_apply, 'success')

    cmd_node_alive = dep_method.kubectl(
      website_location: @website_location,
      s_arguments: "-n instance-#{@website.id} get pods " \
                    "-o=jsonpath='{.items[*].status.containerStatuses[*].state.waiting}'" \
                    " | grep \"CrashLoopBackOff\""
    )

    prepare_ssh_session(cmd_node_alive, 'success', 1)

    cmd_instance_up = dep_method.kubectl(
      website_location: @website_location,
      s_arguments: "-n instance-#{@website.id} get pods " \
                    "-o=jsonpath='{.items[*].status.containerStatuses[*].ready}'" \
                    " | grep -v false"
    )
    prepare_ssh_session(cmd_instance_up, 'success')

    prepare_ssh_session("lssss", 'success')

    assert_scripted do
      begin_ssh
      run_deployer_job

      deployment = @website.deployments.last
      @website.reload

      assert_equal @website.status, Website::STATUS_ONLINE
      assert_equal deployment.status, Deployment::STATUS_SUCCESS
      assert_equal deployment.result['steps'].length, 13 # global, 2 kills, finalize

      assert_equal deployment.result['errors'].length, 0

      # should also have a deployment with events
      assert_equal @website.deployments.last.events.length, 13

      allowed_to = dep_event_exists?(@website.deployments.last.events,
                                     'running', 'allowed to dep')
      assert_equal allowed_to, true

      # verified_event = dep_event_exists?(@website.deployments.last.events,
      #                                   'running', '...verified')
      # assert_equal verified_event, true

      # TODO

      # final_details_event = @website.deployments.last.events.find do |e|
      #  e['update'].andand['details'].andand['result']
      # end

      # assert_not_nil final_details_event
      # assert_equal(final_details_event['update']['details']['url'],
      #             "http://testsite.#{CloudProvider::Manager.base_hostname}/")
    end
  end
end
