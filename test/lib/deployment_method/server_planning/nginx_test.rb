require 'test_helper'

class ServerPlanningNginxTest < ActiveSupport::TestCase
  def setup; end

  test 'gen_nginx_confs without certs' do
    domains = ['what.com', 'www.what.com']
    ports = [9000, 9001]
    opts = { domains: domains, ports: ports }
    results = DeploymentMethod::ServerPlanning::Nginx.gen_nginx_confs(opts)

    assert_includes results, 'server 127.0.0.1:9000'
    assert_includes results, 'server_name  what.com www.what.com;'
    assert_not_includes results, 'listen 443 ssl http2'
  end

  test 'gen_nginx_confs with certs' do
    domains = ['what.com', 'www.what.com']
    ports = [9000, 9001]
    opts = {
      domains: domains,
      ports: ports,
      certs: {
        cert_path: 't/tt',
        cert_key_path: 'a/b'
      }
    }

    results = DeploymentMethod::ServerPlanning::Nginx.gen_nginx_confs(opts)

    assert_includes results, 'server 127.0.0.1:9000'
    assert_includes results, 'server_name  what.com www.what.com;'
    assert_includes results, 'listen 443 ssl http2'
    assert_includes results, 'ssl_certificate t/tt'
    assert_includes results, 'ssl_certificate_key a/b'
  end

  test 'apply' do
    set_dummy_secrets_to(LocationServer.all)
    configs = default_runner_configs
    configs[:execution_method] = DeploymentMethod::ServerPlanning::Nginx.new
    runner = DeploymentMethod::Runner.new('docker', 'private-cloud', configs)
    dep_method = runner.get_execution_method

    cp_orig_config_cmd = configs[:execution_method].cp_original_nginx_configs
    prepare_ssh_session(cp_orig_config_cmd, '')
    restart_cmd = configs[:execution_method].restart
    prepare_ssh_session(restart_cmd, '')

    assert_scripted do
      begin_sftp
      begin_ssh
      dep_method.apply(
        website: default_runner_configs[:website],
        website_location: default_runner_configs[:website_location]
      )

      uploaded_files = Remote::Sftp.get_test_uploaded_files
      assert_equal uploaded_files.length, 1
      puts "uploaded_files = #{uploaded_files.inspect}"
      assert_includes uploaded_files[0][:content], 'upstream backend-http'
      assert_includes uploaded_files[0][:remote_file_path], '/etc/nginx/'
    end
  end
end
