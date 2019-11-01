require 'test_helper'

class ServerPlanningDockerComposeTest < ActiveSupport::TestCase
  def setup; end

  test 'parse_global_containers' do
    set_dummy_secrets_to(LocationServer.all)
    configs = default_runner_configs
    configs[:execution_method] = DeploymentMethod::ServerPlanning::DockerCompose.new
    runner = DeploymentMethod::Runner.new('docker', 'private-cloud', configs)
    dep_method = runner.get_execution_method

    prepare_ssh_session(DeploymentMethod::ServerPlanning::DockerCompose.dind_src_path, '')

    assert_scripted do
      begin_ssh
      dep_method.apply
    end
  end
end
