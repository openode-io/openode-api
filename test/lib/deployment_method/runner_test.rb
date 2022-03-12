# frozen_string_literal: true

require 'test_helper'

class RunnerTest < ActiveSupport::TestCase
  def setup; end

  test 'get deployment method with valid' do
    runner = DeploymentMethod::Runner.new('docker', 'cloud', default_runner_configs)

    assert_equal runner.get_execution_method.class.name, 'DeploymentMethod::DockerCompose'
  end

  test 'get deployment method with invalid' do
    runner = DeploymentMethod::Runner.new('docker2', 'cloud', default_runner_configs)

    begin
      assert_nil runner.get_execution_method
    rescue StandardError
      nil
    end
  end

  test 'get cloud provider internal' do
    runner = DeploymentMethod::Runner.new('docker', 'cloud', default_runner_configs)

    assert_equal runner.get_cloud_provider.class.name, 'CloudProvider::Internal'
  end

  test 'get cloud provider dummy' do
    runner = DeploymentMethod::Runner.new('docker', 'dummy', default_runner_configs)

    assert_equal runner.get_cloud_provider.class.name, 'CloudProvider::Dummy'
  end

  test 'get cloud provider invalid' do
    runner = DeploymentMethod::Runner.new('docker', 'dummy2', default_runner_configs)

    begin
      assert_nil runner.get_cloud_provider
    rescue StandardError
      nil
    end
  end
end
