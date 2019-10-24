# frozen_string_literal: true

require 'test_helper'

class WebsiteTest < ActiveSupport::TestCase
  class Validation < ActiveSupport::TestCase
    test 'should not save required fields' do
      w = Website.new
      assert_not w.save
    end

    test 'should save with all required fields' do
      w = Website.new(
        site_name: 'thisisauniquesite',
        cloud_type: 'cloud',
        user_id: User.first.id,
        type: 'docker',
        status: 'starting',
        domain_type: 'subdomain'
      )

      assert w.save
    end

    test 'invalid site_name with subdomain' do
      w = Website.new(
        site_name: 'thisisauniq.uesite',
        cloud_type: 'cloud',
        user_id: User.first.id,
        type: 'docker',
        status: 'starting',
        domain_type: 'subdomain'
      )

      assert_equal w.save, false
    end

    test 'invalid site_name with custom domain' do
      w = Website.new(
        site_name: 'thisisauniq.--=uesite',
        cloud_type: 'cloud',
        user_id: User.first.id,
        type: 'docker',
        status: 'starting',
        domain_type: 'subdomain'
      )

      assert_equal w.save, false
    end

    # domains:

    test 'getting empty domains' do
      w = Website.where(site_name: 'testsite').first
      w.domains ||= []
      w.save!
      w.reload

      assert w.domains.empty?
    end

    test 'getting domains' do
      w = Website.where(site_name: 'www.what.is').first
      w.domains ||= []
      w.domains << 'www.what.is'
      w.save!
      w.reload

      assert_equal w.domains.length, 1
      assert_equal w.domains[0], 'www.what.is'
    end

    test 'fail with invalid domain' do
      w = Website.where(site_name: 'www.what.is').first
      w.domains ||= []
      w.domains << 'www-what-is'

      assert_equal w.save, false
    end

    test 'domains validation should fail if different domain' do
      w = Website.where(site_name: 'www.what.is').first
      w.domains ||= []
      w.domains << 'www3.www.what2.is'
      w.save

      assert_equal w.valid?, false
    end

    test 'get all custom domain websites' do
      custom_domain_sites = Website.custom_domain

      assert custom_domain_sites.length == 1
      assert custom_domain_sites[0].site_name == 'www.what.is'
    end

    test 'getting configs' do
      w = Website.where(site_name: 'testsite').first
      w.configs = { hello: 'world', field2: 1234 }
      w.save!
      w.reload

      assert_equal w.configs['hello'], 'world'
      assert_equal w.configs['field2'], 1234
    end

    # repo dir
    test 'repo dir' do
      w = Website.where(site_name: 'testsite').first

      assert_equal w.repo_dir, "#{Website::REPOS_BASE_DIR}#{w.user_id}/#{w.site_name}/"
    end

    # change status
    test 'change status with valid status' do
      w = Website.where(site_name: 'testsite').first
      w.change_status!(Website::STATUS_OFFLINE)
      w.reload
      assert_equal w.status, Website::STATUS_OFFLINE
    end

    test 'change status with invalid status' do
      w = Website.where(site_name: 'testsite').first
      w.change_status!('what')
    rescue StandardError => e
      assert_includes e.to_s, 'Wrong status'
      w.reload
      assert_equal w.status, Website::STATUS_ONLINE
    end

    # storage area validation

    test 'storage area validate with valid ones' do
      w = Website.where(site_name: 'testsite').first
      w.storage_areas = ['tmp/', 'what/is/this']
      w.save!
      w.reload

      assert_equal w.storage_areas, ['tmp/', 'what/is/this']
    end

    test 'storage area validate with invalid ones' do
      w = Website.where(site_name: 'testsite').first
      w.storage_areas = ['../tmp/', 'what/is/this']
      w.save

      assert_equal w.valid?, false
    end

    # dns validation

    test 'dns fail if domain not in list' do
      w = Website.where(site_name: 'www.what.is').first
      w.domains = ['www.what.is']
      w.dns = [{ domainName: 'www2.what.is', type: 'A', value: '123' }]
      w.save

      assert_equal w.valid?, false
    end

    test 'dns fail if type invalid' do
      w = Website.where(site_name: 'www.what.is').first
      w.domains = ['www.what.is']
      w.dns = [{ domainName: 'wwww.what.is', type: 'B', value: '123' }]
      w.save

      assert_equal w.valid?, false
    end

    # locations

    test 'locations for a given website' do
      w = Website.where(site_name: 'testsite').first

      assert_equal w.locations.length, 1
      assert_equal w.locations[0].str_id, 'canada'
    end

    # location exists
    test 'location exists' do
      website = default_website
      assert_equal website.location_exists?('canada'), true
    end

    # add_location
    test 'add location fail if subdomain and private server' do
      website = default_website
      CloudProvider::Manager.clear_instance
      CloudProvider::Manager.instance # populate locations
      location = Location.find_by str_id: 'miami-39'

      begin
        website.add_location(location)
        raise 'invalid'
      rescue StandardError => e
        assert_includes(e.inspect.to_s,
                        'This location is available only for custom domains')
      end
    end

    test 'add location happy path' do
      website = default_website
      website.website_locations.destroy_all
      location = Location.find_by str_id: 'canada'

      website.add_location(location)

      assert_equal website.website_locations.reload[0].location.str_id, 'canada'
    end

    # normalize_storage_areas
    test 'normalized_storage_areas with two areas' do
      w = Website.where(site_name: 'testsite').first
      w.storage_areas = ['tmp/', 'what/is/this/']
      w.save
      w.reload

      n_storage_areas = w.normalized_storage_areas

      assert_equal n_storage_areas[0], './tmp/'
      assert_equal n_storage_areas[1], './what/is/this/'
    end

    # can_deploy_to?
    test 'can_deploy_to? simple scenario should pass' do
      website = Website.find_by(site_name: 'testsite')

      can_deploy, = website.can_deploy_to?(website.website_locations.first)
      assert_equal can_deploy, true
    end

    test "can_deploy_to? can't if user not activated" do
      website = Website.find_by(site_name: 'testsite')
      website.user.activated = false
      website.user.save!
      website.user.reload

      can_deploy, msg = website.can_deploy_to?(website.website_locations.first)

      assert_equal can_deploy, false
      assert_includes msg, 'not yet activated'
    end

    test "can_deploy_to? can't if user suspended" do
      website = Website.find_by(site_name: 'testsite')
      website.user.suspended = true
      website.user.save!
      website.user.reload

      can_deploy, msg = website.can_deploy_to?(website.website_locations.first)

      assert_equal can_deploy, false
      assert_includes msg, 'suspended'
    end

    test "can_deploy_to? can't if user does not have any credit" do
      website = Website.find_by(site_name: 'testsite')
      website.user.credits = 0
      website.user.save!
      website.user.reload

      can_deploy, msg = website.can_deploy_to?(website.website_locations.first)

      assert_equal can_deploy, false
      assert_includes msg, 'No credit available'
    end

    # max build duration
    test 'max build duration with default' do
      website = Website.find_by(site_name: 'testsite')
      website.configs ||= {}
      website.configs['MAX_BUILD_DURATION'] = 150
      website.save!
      website.reload

      assert_equal website.max_build_duration, 150
    end

    # extra storage
    test 'extra storage with extra storage' do
      website = default_website
      wl = default_website_location
      wl.extra_storage = 2
      wl.save!

      assert_equal website.total_extra_storage, 2
      assert_equal website.extra_storage?, true
      assert_equal(website.extra_storage_credits_cost_per_hour,
                   2 * 100 * CloudProvider::Internal::COST_EXTRA_STORAGE_GB_PER_HOUR)
    end

    test 'extra storage without extra storage' do
      website = default_website
      wl = default_website_location
      wl.extra_storage = 0
      wl.save!

      assert_equal website.total_extra_storage, 0
      assert_equal website.extra_storage?, false
      assert_equal website.extra_storage_credits_cost_per_hour, 0
    end

    # extra cpus
    test 'extra cpus with extra cpus' do
      website = default_website
      wl = default_website_location
      wl.nb_cpus = 3
      wl.save!

      assert_equal website.total_extra_cpus, 2
      assert_equal(website.extra_cpus_credits_cost_per_hour,
                   2 * 100 * CloudProvider::Internal::COST_EXTRA_CPU_PER_HOUR)
    end

    # spend credits
    test 'spend hourly credits - plan only' do
      website = default_website
      website.credit_actions.destroy_all
      wl = default_website_location
      wl.nb_cpus = 1
      wl.extra_storage = 0
      wl.save!

      website.spend_hourly_credits!

      plan = website.plan

      assert_equal website.credit_actions.reload.length, 1
      ca = website.credit_actions.first

      assert_equal(ca.credits_spent.to_f.round(4),
                   (plan[:cost_per_hour] * 100.0).to_f.round(4))
      assert_equal ca.action_type, CreditAction::TYPE_CONSUME_PLAN
    end

    test 'spend hourly credits - with extra services' do
      website = default_website
      website.credit_actions.destroy_all
      wl = default_website_location
      wl.nb_cpus = 2
      wl.extra_storage = 2
      wl.save!

      website.spend_hourly_credits!

      plan = website.plan

      assert_equal website.credit_actions.reload.length, 3
      credits_actions = website.credit_actions

      assert_equal(credits_actions[0].credits_spent.to_f.round(4),
                   (plan[:cost_per_hour] * 100.0).to_f.round(4))
      assert_equal credits_actions[0].action_type, CreditAction::TYPE_CONSUME_PLAN
      assert_equal credits_actions[1].action_type, CreditAction::TYPE_CONSUME_STORAGE
      assert_equal credits_actions[2].action_type, CreditAction::TYPE_CONSUME_CPU
    end
  end
end
