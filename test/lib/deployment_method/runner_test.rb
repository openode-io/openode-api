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

  test "send crontab with crontab provided" do
    set_dummy_secrets_to(LocationServer.all)
    website = default_website
    website.crontab = "* * * * * ls -la"
    website.save!
    runner = DeploymentMethod::Runner.new("docker", "cloud", dummy_ssh_configs)

    begin_sftp
    runner.execute([
      {
        cmd_name: "send_crontab", options: { is_complex: true, website: website }
      }
    ])
    
    assert_equal Remote::Sftp.get_test_uploaded_files.length, 1
    assert_equal Remote::Sftp.get_test_uploaded_files[0][:content], website.crontab
    assert_equal Remote::Sftp.get_test_uploaded_files[0][:remote_file_path], "#{website.repo_dir}.openode.cron"
  end

  test "send crontab without crontab provided" do
    set_dummy_secrets_to(LocationServer.all)
    website = default_website
    website.crontab = ""
    website.save!
    runner = DeploymentMethod::Runner.new("docker", "cloud", dummy_ssh_configs)

    begin_sftp
    runner.execute([
      {
        cmd_name: "send_crontab", options: { is_complex: true, website: website }
      }
    ])
    
    assert_equal Remote::Sftp.get_test_uploaded_files.length, 0
  end

end
