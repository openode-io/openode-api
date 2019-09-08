require 'test_helper'

class DockerComposeTest < ActiveSupport::TestCase

  def setup

  end

  # default_docker_compose_file

  test "default_docker_compose_file without env file" do
    result = DeploymentMethod::DockerCompose.default_docker_compose_file

    assert_equal result.include?("version: '3'"), true
    assert_equal result.include?("# env_file:"), true
  end

  test "default_docker_compose_file with env file" do
    result = DeploymentMethod::DockerCompose.default_docker_compose_file({
      with_env_file: true
    })

    assert_equal result.include?("version: '3'"), true
    assert_equal result.include?("    env_file:"), true
  end

end
