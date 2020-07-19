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

  test 'extra storage - extra storage cannot be used with replicas > 1' do
    website = default_website
    wl = website.website_locations.first
    wl.extra_storage = 1
    wl.replicas = 2
    wl.save

    assert_equal wl.valid?, false
  end

  test 'extra storage - replicas too low' do
    website = default_website
    wl = website.website_locations.first
    wl.extra_storage = 0
    wl.replicas = 0
    wl.save

    assert_equal wl.valid?, false
  end

  test 'extra storage - replicas too high' do
    website = default_website
    wl = website.website_locations.first
    wl.extra_storage = 0
    wl.replicas = WebsiteLocation::MAX_REPLICAS + 1
    wl.save

    assert_equal wl.valid?, false
  end

  test 'extra storage - using max replicas' do
    website = default_website
    wl = website.website_locations.first
    wl.extra_storage = 0
    wl.replicas = WebsiteLocation::MAX_REPLICAS
    wl.save!

    assert_equal wl.valid?, true
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

  test 'domain with kubernetes subdomain - euro' do
    website = Website.find_by site_name: 'testsite2'
    website.type = Website::TYPE_KUBERNETES

    wl = website.website_locations[0]

    location = Location.find_by str_id: 'eu'
    wl.location_id = location.id
    wl.save!

    assert wl.main_domain == 'testsite2.eu.openode.io'
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

  # notify_force_stop
  test 'notify_force_stop - happy path' do
    website = default_website
    website.notifications.destroy_all
    wl = website.website_locations.first

    reason = 'Out of memory detected'
    wl.notify_force_stop(reason)

    assert_equal wl.website.stop_events.length, 1
    assert_equal wl.website.stop_events.last.obj.dig('reason'), reason

    assert_equal wl.website.notifications.reload.last.content, reason
    assert_equal wl.website.notifications.last.level, 'critical'

    mail_sent = ActionMailer::Base.deliveries.first
    assert_includes mail_sent.subject, 'stopped'
    assert_includes mail_sent.subject, website.site_name
    assert_includes mail_sent.body.raw_source, reason
  end

  test 'notify_force_stop - already notified recently' do
    website = default_website
    website.notifications.destroy_all
    wl = website.website_locations.first

    StopWebsiteEvent.create(website: website, obj: { reason: 'no!' })

    reason = 'Out of memory detected'
    wl.notify_force_stop(reason)

    assert_equal wl.website.stop_events.length, 1
    assert_equal wl.website.stop_events.last.obj.dig('reason'), 'no!'
  end
end
