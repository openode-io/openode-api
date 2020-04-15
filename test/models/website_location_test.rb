# frozen_string_literal: true

require 'test_helper'

class WebsiteLocationTest < ActiveSupport::TestCase
  test 'first website location' do
    website = default_website
    wl = website.website_locations[0]

    assert wl.location.str_id == 'canada'
  end

  test 'fail if two times the same location for a given website' do
    website = default_website

    begin
      WebsiteLocation.create!(
        website: website,
        location: Location.find_by!(str_id: 'canada')
      )
      raise 'invalid'
    rescue StandardError => e
      assert_includes e.inspect.to_s, 'already exists'
    end
  end

  test 'extra storage valid' do
    website = default_website
    wl = website.website_locations[0]
    wl.extra_storage = 5
    wl.save!
  end

  test 'extra storage too high' do
    website = default_website
    wl = website.website_locations[0]
    wl.extra_storage = 11
    wl.save

    assert_equal wl.valid?, false
  end

  test 'extra storage too low' do
    website = default_website
    wl = website.website_locations[0]
    wl.extra_storage = -1
    wl.save

    assert_equal wl.valid?, false
  end

  test 'domain with canada subdomain' do
    website = default_website
    wl = website.website_locations[0]

    assert wl.main_domain == 'testsite.openode.io'
  end

  test 'domain with usa subdomain' do
    website = Website.find_by site_name: 'testsite2'
    wl = website.website_locations[0]

    assert wl.main_domain == 'testsite2.openode.io'
  end

  test 'domain with kubernetes subdomain' do
    website = Website.find_by site_name: 'testsite2'
    website.type = Website::TYPE_KUBERNETES
    wl = website.website_locations[0]

    assert wl.main_domain == 'testsite2.openode.io'
  end

  test 'domain with usa custom domain' do
    website = Website.find_by site_name: 'www.what.is'
    wl = website.website_locations[0]

    assert wl.main_domain == 'www.what.is'
  end

  # root domain of website location
  test 'root domain with usa custom domain' do
    website = Website.find_by site_name: 'www.what.is'
    wl = website.website_locations[0]

    assert wl.root_domain == 'what.is'
  end

  # compute domains of website location
  test 'compute domains with usa custom domain' do
    website = Website.find_by site_name: 'www.what.is'
    website.domains = ['www.what.is', 'www2.www.what.is']
    website.save!
    wl = website.website_locations[0]

    assert wl.compute_domains == ['www.what.is', 'www2.www.what.is']
  end

  test 'compute domains with usa subdomain' do
    website = Website.find_by site_name: 'testsite2'
    wl = website.website_locations[0]

    assert wl.compute_domains == ['testsite2.openode.io']
  end

  test 'compute_a_record_dns with two domains' do
    server = LocationServer.find_by ip: '127.0.0.1'

    domain_names = ['google.com', 'www.google.com', 'www2.www.google.com']
    result =
      WebsiteLocation.compute_a_record_dns(server, domain_names)

    assert_equal result.length, 3
    assert_equal result[0]['name'], ''
    assert_equal result[0]['domainName'], 'google.com'
    assert_equal result[0]['type'], 'A'
    assert_equal result[0]['value'], '127.0.0.1'

    assert_equal result[1]['domainName'], 'www.google.com'
    assert_equal result[1]['name'], 'www'
    assert_equal result[1]['type'], 'A'
    assert_equal result[1]['value'], '127.0.0.1'

    assert_equal result[2]['domainName'], 'www2.www.google.com'
    assert_equal result[2]['name'], 'www2.www'
    assert_equal result[2]['type'], 'A'
    assert_equal result[2]['value'], '127.0.0.1'
  end

  # compute_dns
  test 'compute dns with one domain and no dns entry' do
    website = Website.find_by site_name: 'www.what.is'
    website.domains = ['www.what.is']
    website.dns = []
    website.save!
    wl = website.website_locations[0]

    assert wl.compute_dns == []
  end

  test 'compute dns with one domain and one dns entry' do
    website = Website.find_by site_name: 'www.what.is'
    website.domains = ['www.what.is']

    entry1 = {
      name: 'www',
      domainName: 'www.what.is',
      type: 'A',
      value: '127.0.0.10'
    }

    website.dns = [entry1]
    website.save!
    website.reload
    wl = website.website_locations[0]

    result = wl.compute_dns

    assert_equal result.length, 1
    assert_equal result[0]['name'], 'www'
    assert_equal result[0]['domainName'], 'www.what.is'
    assert_equal result[0]['type'], 'A'
    assert_equal result[0]['value'], '127.0.0.10'
    assert_equal result[0]['id'], WebsiteLocation.dns_entry_to_id(entry1)
  end

  test 'compute dns with one domain, one dns entry, and auto a' do
    website = Website.find_by site_name: 'www.what.is'
    website.domains = ['www.what.is']

    entry1 = {
      name: 'www',
      domainName: 'www.what.is',
      type: 'A',
      value: '127.0.0.10'
    }

    website.dns = [entry1]
    website.save!
    website.reload
    wl = website.website_locations[0]

    result = wl.compute_dns(with_auto_a: true)

    assert_equal result.length, 2
    assert_equal result[0]['name'], 'www'
    assert_equal result[0]['domainName'], 'www.what.is'
    assert_equal result[0]['type'], 'A'
    assert_equal result[0]['value'], '127.0.0.10'
    assert_equal result[0]['id'], WebsiteLocation.dns_entry_to_id(entry1)

    assert_equal result[1]['name'], 'www'
    assert_equal result[1]['domainName'], 'www.what.is'
    assert_equal result[1]['type'], 'A'
    assert_equal result[1]['value'], wl.location_server.ip
    assert_equal result[1]['id'], WebsiteLocation.dns_entry_to_id(
      name: 'www',
      domainName: 'www.what.is',
      type: 'A',
      value: wl.location_server.ip
    )
  end

  # update_remote_dns
  test 'update_remote_dns with two sitenames having the same root domain' do
    website = Website.find_by site_name: 'app.what.is'
    website.domains = ['app.what.is']
    website.dns = []
    website.save!
    wl = website.website_locations[0]

    actions = wl.update_remote_dns(with_auto_a: true)

    assert_equal actions[:deleted], []
    assert_equal actions[:created][0]["name"], "app"
    assert_equal actions[:created][0]["type"], "A"
    assert_equal actions[:created][0]["value"], wl.location_server.ip
  end

  # generic root domain
  test 'root domain of google' do
    assert WebsiteLocation.root_domain('www.google.com') == 'google.com'
  end

  test 'root domain of .nl' do
    assert WebsiteLocation.root_domain('dev.api.abnbouw.nl') == 'abnbouw.nl'
  end

  # available_plans
  test 'available plans cloud' do
    expected_plans = CloudProvider::Manager.instance.first_of_type('internal').plans
    w = Website.find_by site_name: 'testsite'
    website_location = w.website_locations.first

    plans = website_location.available_plans

    assert_equal plans.length, expected_plans.length
    assert_equal plans[0][:id], 'open-source'
  end

  # allocate_ports!
  test 'allocate ports' do
    w = Website.find_by site_name: 'testsite2'
    website_location = w.website_locations.first

    website_location.port = nil
    website_location.second_port = nil
    website_location.save

    website_location.allocate_ports!
    website_location.reload

    port = website_location.port
    second_port = website_location.second_port

    assert_equal port.between?(5000, 65_534), true
    assert_equal second_port.between?(5000, 65_534), true

    website_location.allocate_ports!
    website_location.reload

    assert_equal website_location.port, port
    assert_equal website_location.second_port, second_port
  end

  # ports
  test 'all ports, all defined' do
    website_location = default_website_location

    website_location.port = 12_345
    website_location.second_port = 12_346
    website_location.save

    assert_equal website_location.ports.length, 2
    assert_equal website_location.ports[0], 12_345
    assert_equal website_location.ports[1], 12_346
  end

  test 'all ports, second port missing' do
    website_location = default_website_location

    website_location.port = 12_345
    website_location.second_port = nil
    website_location.save

    assert_equal website_location.ports.length, 1
    assert_equal website_location.ports[0], 12_345
  end

  # internal domains
  test 'INTERNAL_DOMAINS' do
    assert_equal WebsiteLocation.internal_domains.length, 2
    assert_includes WebsiteLocation.internal_domains, 'openode.io'
    assert_includes WebsiteLocation.internal_domains, 'openode.dev'
  end

  # nb cpus
  test 'nb_cpus invalid if < 1' do
    wl = default_website_location

    wl.nb_cpus = 0
    wl.save

    assert_equal wl.valid?, false
  end

  test 'nb_cpus invalid if > 0.75 of location server cpus' do
    wl = default_website_location

    wl.nb_cpus = 7
    wl.save

    assert_equal wl.valid?, false
  end

  test 'nb_cpus valid if < 0.75 of location server cpus' do
    wl = default_website_location

    wl.nb_cpus = 5
    wl.save

    assert_equal wl.valid?, true
  end

  # gen_ssh_key!
  test 'gen_ssh_key' do
    wl = default_website_location
    wl.gen_ssh_key!
    wl.reload

    assert_equal wl.secret[:public_key].include?('ssh-rsa'), true
    assert_equal wl.secret[:private_key].include?('PRIVATE KEY'), true
  end

  # add_server!
  test 'add_server! when not exists' do
    wl = default_website_location
    server = wl.add_server!(
      ip: '127.0.0.15',
      ram_mb: 128,
      cpus: 1,
      disk_gb: 200,
      cloud_type: 'private-cloud'
    )

    assert_equal server.ip, '127.0.0.15'
    assert_equal wl.location_server.ip, '127.0.0.15'
    assert_equal wl.location_id, wl.location_id
    assert_equal wl.website.events[0].obj['title'], 'DNS update'
    assert_equal wl.website.events.length, 1

    # if create with same ip, should skip it
    wl.add_server!(
      ip: '127.0.0.15',
      ram_mb: 128,
      cpus: 1,
      disk_gb: 200,
      cloud_type: 'private-cloud'
    )

    assert_equal wl.website.events.length, 1
  end

  # change_storage
  test 'change_storage with user having orders' do
    website = default_website
    wl = website.website_locations.first
    before_extra_storage = wl.extra_storage
    wl.change_storage!(1)

    wl.reload

    assert_equal wl.extra_storage, before_extra_storage + 1
  end

  test 'change_storage with user not having orders should fail' do
    website = default_website
    website.user.orders.each(&:destroy)
    wl = website.website_locations.first
    before_extra_storage = wl.extra_storage

    assert_raises StandardError do
      wl.change_storage!(1)
    end

    wl.reload

    assert_equal wl.extra_storage, before_extra_storage
  end

  # TODO: other tests
end
