# frozen_string_literal: true

require 'test_helper'

class ManagerTest < ActiveSupport::TestCase
  def setup
    CloudProvider::Manager.clear_instance
  end

  test 'instance initializes' do
    manager = CloudProvider::Manager.instance

    assert_equal manager, CloudProvider::Manager.instance

    # should have initialized the canada2 test
    location = Location.find_by! str_id: 'canada2'
    assert_equal location.present?, true
    assert_equal location.str_id, 'canada2'
    assert_equal location.full_name, 'Montreal (Canada2)'
    assert_equal location.country_fullname, 'Canada2'
  end

  test 'available locations' do
    locations = CloudProvider::Manager.instance.available_locations
    assert_equal locations.length >= 3, true

    assert_equal locations.find { |l| l[:id] == 'canada' }[:id], 'canada'
    assert_equal locations.find { |l| l[:id] == 'canada2' }[:id], 'canada2'
    assert_equal locations.find { |l| l[:id] == 'usa' }[:id], 'usa'
  end

  test 'should create internal location server and secret properly' do
    locations = CloudProvider::Manager.instance

    ls = LocationServer.find_by! ip: '127.0.0.100'

    assert_equal ls.ip, '127.0.0.100'
    assert_equal ls.secret[:user], 'root'
    assert_equal ls.secret[:password], 'hellorroot'
    assert_equal ls.ram_mb, 5000
    assert_equal ls.cpus, 2
    assert_equal ls.disk_gb, 200
  end

  test 'should create internal location server and private key' do
    locations = CloudProvider::Manager.instance

    ls = LocationServer.find_by! ip: '127.0.0.101'

    assert_equal ls.ip, '127.0.0.101'
    assert_equal ls.secret[:private_key], "-----BEGIN RSA PRIVATE KEY-----\n" \
                                          "AAA\n" \
                                          "BBB\n" \
                                          "CCC\n" \
                                          "-----END RSA PRIVATE KEY-----\n"
  end

  test 'first_of_type with existing' do
    manager = CloudProvider::Manager.instance

    assert_equal manager.first_of_type('internal').class.name,
                 'CloudProvider::Internal'
  end

  test 'first_of_type with invalid' do
    manager = CloudProvider::Manager.instance

    assert_nil manager.first_of_type('external')
  end

  test 'base application hostname' do
    manager = CloudProvider::Manager.instance

    assert_equal manager.base_hostname, 'openode.io'
  end

  test 'get config application' do
    manager = CloudProvider::Manager.instance

    assert_equal manager.application['hostname_private_cloud'], 'openode.dev'
  end
end
