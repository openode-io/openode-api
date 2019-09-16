require 'test_helper'

class RunnerTest < ActiveSupport::TestCase

  def setup

  end

  test "get deployment method with valid" do
    runner = DeploymentMethod::Runner.new("docker", "cloud", {})

    assert_equal runner.get_deployment_method.class.name, "DeploymentMethod::DockerCompose"
  end

  test "get deployment method with invalid" do
    runner = DeploymentMethod::Runner.new("docker2", "cloud", {})

    assert_nil runner.get_deployment_method rescue nil
  end

  test "get cloud provider internal" do
    runner = DeploymentMethod::Runner.new("docker", "cloud", {})

    assert_equal runner.get_cloud_provider.class.name, "CloudProvider::Internal"
  end

  test "get cloud provider dummy" do
    runner = DeploymentMethod::Runner.new("docker", "dummy", {})

    assert_equal runner.get_cloud_provider.class.name, "CloudProvider::Dummy"
  end

  test "get cloud provider invalid" do
    runner = DeploymentMethod::Runner.new("docker", "dummy2", {})

    assert_nil runner.get_cloud_provider rescue nil

  end

end
