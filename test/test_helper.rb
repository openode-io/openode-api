ENV['RAILS_ENV'] = 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'net/ssh/test'
require 'net/sftp'
require 'webmock/minitest'

require 'simplecov'
SimpleCov.start

class ActiveSupport::TestCase
  include Net::SSH::Test

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  setup do
    http_stubs = [
      {
        url: "https://api.vultr.com/v1/plans/list",
        method: :get,
        content_type: "application/json",
        response_status: 200,
        response_path: "test/fixtures/http/cloud_provider/vultr/plans_list.json"
      },
      {
        url: "https://api.vultr.com/v1/regions/list",
        method: :get,
        content_type: "application/json",
        response_status: 200,
        response_path: "test/fixtures/http/cloud_provider/vultr/regions_list.json"
      }
    ]

    http_stubs.each do |http_stub|
      stub_request(http_stub[:method], http_stub[:url]).
        to_return(status: http_stub[:response_status], 
          body: IO.read(http_stub[:response_path]), 
          headers: { content_type: http_stub[:content_type] })
    end

  end

  def set_dummy_secrets_to(servers)
    servers.each do |server|
      server.save_secret!({
        user: "myuser",
        password: "mypass",
        private_key: "toto"
      })
    end
  end

  def prepare_ssh_session(cmd, output, exit_code = 0)
    story do |session|
      channel = session.opens_channel
      channel.sends_exec cmd
      channel.gets_data output
      channel.gets_exit_status(exit_code)
      channel.gets_close
      channel.sends_close
    end
  end

  def prepare_ssh_ensure_remote_repository(website)
    prepare_ssh_session("mkdir -p #{website.repo_dir}", "")
  end

  def prepare_send_remote_repo(website, arch_filename, output)
    cmd = DeploymentMethod::DockerCompose.new.uncompress_remote_archive({
      repo_dir: website.repo_dir,
      archive_path: "#{website.repo_dir}#{arch_filename}"
    })

    prepare_ssh_session(cmd, output)
  end

  def begin_sftp
    Remote::Sftp.set_conn_test("dummy")
  end

  def begin_ssh
    Remote::Ssh.set_conn_test(connection)
  end

  def default_website
    Website.find_by site_name: "testsite"
  end

  def default_website_location
    default_website.website_locations.first
  end

  def dummy_ssh_configs
    {
      host: "test.com",
      secret: {
        user: "user",
        password: "123456"
      },
      website: default_website,
      website_location: default_website_location
    }
  end

  def default_runner_configs
    {
      host: "test.com",
      secret: {
        user: "user",
        password: "123456"
      },
      website: default_website,
      website_location: default_website_location
    }
  end

  def prepare_default_deployment_method
    set_dummy_secrets_to(LocationServer.all)
    runner = DeploymentMethod::Runner.new("docker", "cloud", default_runner_configs)
    runner.get_deployment_method
  end

  def prepare_default_ports
    website_location = default_website_location
    website_location.port = 33129
    website_location.second_port = 33121
    website_location.running_port = 33129
    website_location.save!
  end

  def prepare_default_kill_all(dep_method)
    cmd = dep_method.global_containers({})
    prepare_ssh_session(cmd, IO.read("test/fixtures/docker/global_containers.txt"))
    prepare_ssh_session(dep_method.kill_global_container({ id: "b3621dd9d4dd" }), "killed b3621dd9d4dd")
    prepare_ssh_session(dep_method.kill_global_container({ id: "32bfe26a2712" }), "killed 32bfe26a2712")
  end

  def default_user
    User.find_by email: "myadmin@thisisit.com"
  end

  def base_params
    {
      version: InstancesController::MINIMUM_CLI_VERSION,
      location_str_id: "canada"
    }
  end

  def default_headers_auth
    {
      "x-auth-token": "1234s56789"
    }
  end



  # Add more helper methods to be used by all tests here...
end
