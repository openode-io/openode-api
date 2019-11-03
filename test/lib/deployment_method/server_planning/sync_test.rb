require 'test_helper'

class ServerPlanningSyncTest < ActiveSupport::TestCase
  def setup; end

  test 'sync apply' do
    set_dummy_secrets_to(LocationServer.all)
    configs = default_runner_configs
    configs[:execution_method] = DeploymentMethod::ServerPlanning::Sync.new
    runner = DeploymentMethod::Runner.new('docker', 'private-cloud', configs)
    dep_method = runner.get_execution_method

    mkdir_cmd = configs[:execution_method].sync_mk_src_dir
    prepare_ssh_session(mkdir_cmd, '')

    assert_scripted do
      begin_sftp
      begin_ssh
      dep_method.apply({})

      uploaded_files = Remote::Sftp.get_test_uploaded_files
      assert_equal uploaded_files.length, 1
      assert_includes uploaded_files[0][:content], 'const fs = '
      assert_includes uploaded_files[0][:remote_file_path], 'lib/lfiles.js'
    end
  end
end
