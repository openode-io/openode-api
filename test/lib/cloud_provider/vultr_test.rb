# frozen_string_literal: true

require 'test_helper'

class CloudProviderVultrTest < ActiveSupport::TestCase
  test 'plans' do
    provider = CloudProvider::Manager.instance.first_of_type('vultr')

    plans = provider.plans

    assert_equal plans.length, 8
    assert_equal plans[0][:id], '1024-MB-201'
    assert_equal plans[0][:internal_id], '1024-MB-201'
    assert_equal plans[0][:short_name], '1024-MB-201'
    assert_equal plans[0][:type], CloudProvider::Vultr::TYPE
    assert_equal plans[0][:name], '1024 MB RAM,25 GB SSD,1.00 TB BW'
    assert_equal plans[0][:ram], 1024
    assert_equal plans[0][:cost_per_hour], 0.01075268817204301
    assert_equal plans[0][:cost_per_month], 8.0

    assert_equal plans[7][:id], '98304-MB-208'
  end

  test 'plans_at with existing' do
    provider = CloudProvider::Manager.instance.first_of_type('vultr')
    provider.initialize_locations

    location = Location.find_by str_id: 'singapore-40'

    plans = provider.plans_at(location.str_id)

    assert_equal plans.length, 7

    find_one = plans.find { |plan| plan[:id] == '1024-MB-201' }

    assert_equal find_one[:id], '1024-MB-201'

    plans.each do |plan|
      assert_equal plan[:type], CloudProvider::Vultr::TYPE
    end
  end

  test 'os_list' do
    provider = CloudProvider::Manager.instance.first_of_type('vultr')
    oses = provider.os_list

    assert_equal oses.length, 25
    assert_equal oses[0]['name'], 'CentOS 6 x64'
  end

  test 'find startup script' do
    provider = CloudProvider::Manager.instance.first_of_type('vultr')
    script = provider.find_startup_script('init base debian')

    assert_equal script['name'], 'init base debian'
  end

  test 'find firewall' do
    provider = CloudProvider::Manager.instance.first_of_type('vultr')
    firewall = provider.find_firewall_group('base')

    assert_equal firewall['description'], 'base'
  end

  test 'create ssh key' do
    website_location = default_website_location
    website_location.gen_ssh_key!
    provider = CloudProvider::Manager.instance.first_of_type('vultr')

    provider.create_ssh_key!('hello-world', website_location.secret[:public_key])
  end

  test 'allocate' do
    website = default_website
    website.account_type = 'plan-201'
    website.site_name = 'thisisatest.com'
    website.domains = ['thisisatest.com']
    website.domain_type = 'custom_domain'
    website.save
    website_location = website.website_locations.first
    website_location.location.str_id = 'alaska-6'
    website_location.location.save

    provider = CloudProvider::Manager.instance.first_of_type('vultr')

    provider.allocate(website: website, website_location: website_location)

    website.reload

    assert_equal website.data['privateCloudInfo']['SUBID'], '30303641'
    assert_equal website.data['privateCloudInfo']['SSHKEYID'], '5da3d3a1affa7'
  end

  test 'server info' do
    provider = CloudProvider::Manager.instance.first_of_type('vultr')

    result = provider.server_info(SUBID: '123456789')

    assert_equal result['SUBID'], '30751551'
    assert_equal result['main_ip'], '95.180.134.210'
  end

  # create openode server
  test 'create_openode_server!' do
    wl = default_website_location
    provider = CloudProvider::Manager.instance.first_of_type('vultr')

    info = provider.server_info(SUBID: '123456789')

    created_server = provider.create_openode_server!(wl, info)

    assert_equal wl.location_server.ip, created_server.ip
    assert_equal created_server.ip, '95.180.134.210'
    assert_equal created_server.ram_mb, 1024
    assert_equal created_server.cpus, 1
    assert_equal created_server.disk_gb, 25
    assert_equal created_server.cloud_type, 'private-cloud'
  end

  # save password
  test 'save password - happy path' do
    wl = default_website_location
    wl.gen_ssh_key!
    provider = CloudProvider::Manager.instance.first_of_type('vultr')

    info = provider.server_info(SUBID: '123456789')

    created_server = provider.create_openode_server!(wl, info)

    provider.save_password(wl, created_server, info)

    the_secret = created_server.secret

    assert_equal the_secret[:info][:main_ip], '95.180.134.210'
    assert_includes the_secret[:public_key], 'ssh-rsa '
    assert_includes the_secret[:private_key], 'BEGIN RSA PRIVATE KEY'
  end
end
