# frozen_string_literal: true

require 'test_helper'

class PrivateCloudTest < ActionDispatch::IntegrationTest
  def prepare_custom_domain_with_vultr
    website = default_website
    website.account_type = 'plan-201'
    website.site_name = 'thisisatest.com'
    website.domains = ['thisisatest.com']
    website.domain_type = 'custom_domain'
    website.cloud_type = 'private-cloud'
    website.save!
    website_location = website.website_locations.first
    website_location.location.str_id = 'alaska-6'
    website_location.location.save!

    [website, website_location]
  end

  test 'POST /instances/:instance_id/allocate' do
    website, = prepare_custom_domain_with_vultr

    post '/instances/thisisatest.com/allocate?location_str_id=alaska-6',
         as: :json,
         params: {},
         headers: default_headers_auth

    website.reload

    assert_response :success
    assert_equal response.parsed_body['status'], 'Instance creating...'
    assert_equal website.data['privateCloudInfo']['SUBID'], '30303641'
    assert_equal website.data['privateCloudInfo']['SSHKEYID'], '5da3d3a1affa7'
  end

  test 'POST /instances/:instance_id/allocate fail if already allocated' do
    website, = prepare_custom_domain_with_vultr
    website.data = { 'privateCloudInfo' => { 'SUBID' => 'asdf' } }
    website.save

    post '/instances/thisisatest.com/allocate?location_str_id=alaska-6',
         as: :json,
         params: {},
         headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['success'], 'Instance already allocated'
  end

  test 'POST /instances/:instance_id/allocate fail no credit' do
    website, = prepare_custom_domain_with_vultr
    website.user.credits = 0
    website.user.save

    post '/instances/thisisatest.com/allocate?location_str_id=alaska-6',
         as: :json,
         params: {},
         headers: default_headers_auth

    assert_response :bad_request
  end

  # apply

  test 'POST /instances/:instance_id/apply should fail if not allocated' do
    website = Website.find_by! site_name: 'testprivatecloud'
    website.data = {}
    website.save!

    post '/instances/testprivatecloud/apply?location_str_id=usa',
         as: :json,
         params: {},
         headers: default_headers_auth

    assert_response :bad_request
    assert_includes response.parsed_body.to_s, 'requires to be already allocated'
  end

  test 'POST /instances/:instance_id/apply should fail if not private cloud' do
    website = Website.find_by! site_name: 'testprivatecloud'
    website.cloud_type = 'cloud'
    website.data = {}
    website.save!

    post '/instances/testprivatecloud/apply?location_str_id=usa',
         as: :json,
         params: {},
         headers: default_headers_auth

    assert_response :bad_request
    assert_includes response.parsed_body.to_s, 'must be private cloud-based'
  end

  test 'POST /instances/:instance_id/apply happy path' do
    set_dummy_secrets_to(LocationServer.all)

    website = Website.find_by! site_name: 'testprivatecloud'
    website.cloud_type = 'private-cloud'
    website.data = { 'privateCloudInfo': { 'hello': 'world' } }
    website.save!

    mkdir_sync_cmd = DeploymentMethod::ServerPlanning::Sync.new.sync_mk_src_dir
    prepare_ssh_session(mkdir_sync_cmd, '')

    mkdir_compose_cmd = DeploymentMethod::ServerPlanning::DockerCompose.dind_mk_src_dir
    prepare_ssh_session(mkdir_compose_cmd, '')

    exec_method_nginx = DeploymentMethod::ServerPlanning::Nginx.new
    nginx_cp_orig_config_cmd = exec_method_nginx.cp_original_nginx_configs
    prepare_ssh_session(nginx_cp_orig_config_cmd, '')
    nginx_restart_cmd = exec_method_nginx.restart
    prepare_ssh_session(nginx_restart_cmd, 'restarted nginx')

    assert_scripted do
      begin_sftp
      begin_ssh
      post '/instances/testprivatecloud/apply?location_str_id=usa',
           as: :json,
           params: {},
           headers: default_headers_auth

      assert_response :success
      assert_includes response.parsed_body.to_s, 'restarted nginx'
    end
  end

  # private_cloud_info
  test 'POST /instances/:instance_id/private-cloud-info - happy path' do
    website = Website.find_by! site_name: 'testprivatecloud'
    wl = website.website_locations.first
    wl.gen_ssh_key!
    website.cloud_type = 'private-cloud'
    website.data = { 'privateCloudInfo': { 'SUBID': '123456789' } }
    website.save!

    post '/instances/testprivatecloud/private-cloud-info?location_str_id=usa',
         as: :json,
         params: {},
         headers: default_headers_auth

    wl.reload

    assert_response :success
    assert_equal response.parsed_body['installation_status'], 'ready'
    assert_equal response.parsed_body['SUBID'], '30751551'
    assert_equal wl.location_server.ip, '95.180.134.210'

    assert_equal wl.location_server.secret[:info].present?, true
    assert_equal wl.location_server.secret[:public_key].present?, true
    assert_equal wl.location_server.secret[:private_key].present?, true
  end
end
