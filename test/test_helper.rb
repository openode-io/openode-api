# frozen_string_literal: true

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

  http_stubs = [
    {
      url: 'https://api.vultr.com/v1/plans/list',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/plans_list.json'
    },
    {
      url: 'https://api.vultr.com/v1/server/list?SUBID=123456789',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/server_list_id.json'
    },
    {
      url: 'https://api.vultr.com/v1/dns/list',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/dns_list.json'
    },
    {
      url: 'https://api.vultr.com/v1/dns/records?domain=openode.io',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/domain_records_openode.json'
    },
    {
      url: 'https://api.vultr.com/v1/dns/records?domain=what.is',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/domain_records_what_is.json'
    },
    {
      url: 'https://api.vultr.com/v1/regions/list',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/regions_list.json'
    },
    {
      url: 'https://api.vultr.com/v1/os/list',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/os_list.json'
    },
    {
      url: 'https://api.vultr.com/v1/startupscript/list',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/startup_scripts_list.json'
    },
    {
      url: 'https://api.vultr.com/v1/firewall/group_list',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/firewall_group_list.json'
    },
    {
      url: 'https://api.vultr.com/v1/server/destroy',
      method: :post,
      with: {
        body: { 'SUBID' => 'mysubid1' }
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/empty.json'
    },
    {
      url: 'https://api.vultr.com/v1/dns/create_domain',
      method: :post,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/empty_str.json'
    },
    {
      url: 'https://api.vultr.com/v1/dns/create_record',
      method: :post,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/empty_str.json'
    },
    {
      url: 'https://api.vultr.com/v1/dns/delete_record',
      method: :post,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/empty_str.json'
    },
    {
      url: 'https://api.vultr.com/v1/sshkey/destroy',
      method: :post,
      with: {
        body: { 'SSHKEYID' => 'mysshkeyid' }
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/empty.json'
    },
    {
      url: 'https://api.vultr.com/v1/sshkey/create',
      method: :post,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/ssh_key_create.json'
    },
    {
      url: 'https://api.vultr.com/v1/server/create',
      method: :post,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/server_create.json'
    },
    {
      url: 'http://95.180.134.210/',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/openode_ready.txt'
    },
    {
      url: 'http://95.180.134.211/',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/empty.json'
    }
  ]

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  setup do
    http_stubs.each do |http_stub|
      stub_request(http_stub[:method], http_stub[:url])
        .with(body: http_stub[:with][:body])
        .to_return(status: http_stub[:response_status],
                   body: IO.read(http_stub[:response_path]),
                   headers: { content_type: http_stub[:content_type] })
    end
  end

  def set_dummy_secrets_to(servers)
    servers.each do |server|
      server.save_secret!(
        user: 'myuser',
        password: 'mypass',
        private_key: 'toto'
      )
    end
  end

  def prepare_cloud_provider_manager
    CloudProvider::Manager.clear_instance
    CloudProvider::Manager.instance
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
    prepare_ssh_session("mkdir -p #{website.repo_dir}", '')
  end

  def prepare_send_remote_repo(website, arch_filename, output)
    cmd = DeploymentMethod::DockerCompose.new.uncompress_remote_archive(
      repo_dir: website.repo_dir,
      archive_path: "#{website.repo_dir}#{arch_filename}"
    )

    prepare_ssh_session(cmd, output)
  end

  def begin_sftp
    Remote::Sftp.set_conn_test('dummy')
  end

  def begin_ssh
    Remote::Ssh.set_conn_test(connection)
  end

  def default_website
    Website.find_by site_name: 'testsite'
  end

  def default_website_location
    default_website.website_locations.first
  end

  def dummy_ssh_configs
    {
      host: 'test.com',
      secret: {
        user: 'user',
        password: '123456'
      },
      website: default_website,
      website_location: default_website_location
    }
  end

  def add_collaborator_for(user, website)
    Collaborator.create(user: user, website: website)
  end

  def default_runner_configs
    {
      host: 'test.com',
      secret: {
        user: 'user',
        password: '123456'
      },
      website: default_website,
      website_location: default_website_location
    }
  end

  def prepare_default_execution_method
    set_dummy_secrets_to(LocationServer.all)
    runner = DeploymentMethod::Runner.new('docker', 'cloud', default_runner_configs)
    runner.get_execution_method
  end

  def prepare_default_ports
    website_location = default_website_location
    website_location.port = 33_129
    website_location.second_port = 33_121
    website_location.running_port = 33_129
    website_location.save!
  end

  def prepare_default_kill_all(dep_method)
    cmd = dep_method.global_containers({})
    prepare_ssh_session(cmd, IO.read('test/fixtures/docker/global_containers.txt'))
    prepare_ssh_session(dep_method.kill_global_container(id: 'b3621dd9d4dd'), 'killed b3621dd9d4dd')
    prepare_ssh_session(dep_method.kill_global_container(id: '32bfe26a2712'), 'killed 32bfe26a2712')
  end

  def dep_event_exists?(events, status, update)
    events.any? { |e| e['update'].include?(update) && e['status'] == status }
  end

  def prepare_logs_container(dep_method, website, container_id, result = 'done_logs')
    website.container_id = nil
    prepare_ssh_session(dep_method.logs(container_id: container_id, nb_lines: 10_000,
                                        website: website),
                        result)
  end

  def prepare_get_docker_compose(dep_method, website)
    cmd_get_docker_compose = dep_method.get_file(repo_dir: website.repo_dir,
                                                 file: 'docker-compose.yml')
    basic_docker_compose = IO.read('test/fixtures/docker/docker-compose.txt')
    prepare_ssh_session(cmd_get_docker_compose, basic_docker_compose)
  end

  def prepare_front_container(dep_method, website, website_location, response = '')
    options = {
      in_port: 80,
      website: website,
      website_location: website_location,
      ensure_exit_code: 0,
      limit_resources: true
    }

    prepare_ssh_session(dep_method.front_container(options), response)
  end

  def prepare_docker_compose(dep_method, front_container_id, response = '')
    cmd = dep_method.docker_compose(front_container_id: front_container_id)
    prepare_ssh_session(cmd, response)
  end

  def expect_global_container(dep_method)
    cmd = dep_method.global_containers({})
    prepare_ssh_session(cmd, IO.read('test/fixtures/docker/global_containers.txt'))
  end

  def default_user
    User.find_by email: 'myadmin@thisisit.com'
  end

  def base_params
    {
      version: InstancesController::MINIMUM_CLI_VERSION,
      location_str_id: 'canada'
    }
  end

  def default_headers_auth
    {
      "x-auth-token": '1234s56789'
    }
  end

  def super_admin_headers_auth
    {
      "x-auth-token": '12345678'
    }
  end

  # Add more helper methods to be used by all tests here...
end
