
require 'test_helper'

class WebsiteTest < ActiveSupport::TestCase
  setup do
    reset_emails
  end

  test 'invalid site_name with subdomain' do
    w = Website.new(
      site_name: 'thisisauniq.uesite',
      cloud_type: 'cloud',
      user_id: default_user.id,
      type: 'docker',
      status: 'starting',
      domain_type: 'subdomain'
    )

    w.validate_site_name

    assert_includes w.errors.inspect.to_s, "should not container a dot"
  end

  test 'should default status if not specified' do
    w = Website.new(
      site_name: 'thisisauniquesite',
      cloud_type: 'cloud',
      user_id: default_user.id,
      type: 'docker',
      domain_type: 'subdomain'
    )

    w.save!
    w.reload

    assert_equal w.status, Website::DEFAULT_STATUS
  end

  test 'destroying a website should destroy its secret if any' do
    w = Website.create(
      site_name: 'thisisauniquesite',
      cloud_type: 'cloud',
      user_id: default_user.id,
      type: 'docker',
      domain_type: 'subdomain'
    )

    w.save_secret!(what: 'is')

    vault = w.vault

    w.destroy

    assert_equal Vault.exists?(id: vault.id), false
  end

  test 'invalid site_name with custom domain' do
    w = Website.new(
      site_name: 'thisisauniq.--=uesite',
      cloud_type: 'cloud',
      user_id: default_user.id,
      type: 'docker',
      status: 'starting',
      domain_type: 'subdomain'
    )

    assert_equal w.save, false
  end

  test 'large plans are only for paid users' do
    plans = CloudProvider::Manager.instance.available_plans
    large_plan = plans.find { |p| p[:ram] > Website::MAX_RAM_PLAN_WITHOUT_PAID_ORDER }
    default_user.orders.each(&:destroy)

    w = Website.new(
      site_name: 'test3344',
      cloud_type: 'cloud',
      user_id: default_user.id,
      domain_type: 'subdomain',
      account_type: large_plan[:internal_id]
    )

    assert_equal w.save, false
    assert_includes w.errors.inspect.to_s, "Maximum available plan"
    assert_includes w.errors.inspect.to_s, "100 MB RAM"
  end

  test 'using large plans successfully' do
    plans = CloudProvider::Manager.instance.available_plans
    large_plan = plans.find { |p| p[:ram] > Website::MAX_RAM_PLAN_WITHOUT_PAID_ORDER }

    assert default_user.orders?

    w = Website.new(
      site_name: 'test3344',
      cloud_type: 'cloud',
      user_id: default_user.id,
      domain_type: 'subdomain',
      account_type: large_plan[:internal_id]
    )

    assert_equal w.save, true
  end

  # valid_domain?
  test 'domain_valid? - google.com' do
    assert_equal Website.domain_valid?("google.com"), true
  end

  test 'domain_valid? - www.google.com' do
    assert_equal Website.domain_valid?("www.google.com"), true
  end

  test 'domain_valid? - long last part' do
    assert_equal Website.domain_valid?("rnd.wedding"), true
  end

  test 'domain_valid? - long last part, alternate' do
    assert_equal Website.domain_valid?("rnd.wedding"), true
  end

  # scopes
  test 'having extra storage' do
    reset_all_extra_storage

    w = default_website
    wl = w.website_locations.first
    wl.extra_storage = 2
    wl.save!

    websites_with_storage = Website.having_extra_storage

    assert_equal websites_with_storage.count, 1
    assert_equal websites_with_storage.first.id, w.id
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

    assert custom_domain_sites.length == 2
    assert custom_domain_sites[0].site_name == 'www.what.is'
    assert custom_domain_sites[1].site_name == 'app.what.is'
  end

  test 'subdomain? with subdomain' do
    assert_equal default_website.subdomain?, true
  end

  test 'subdomain? with custom domain' do
    assert_equal default_custom_domain_website.subdomain?, false
  end

  test 'custom_domain? with subdomain' do
    assert_equal default_website.custom_domain?, false
  end

  test 'custom_domain? with custom domain' do
    assert_equal default_custom_domain_website.custom_domain?, true
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

  # online? offline?
  test 'online? - if online' do
    w = default_website
    w.change_status!(Website::STATUS_ONLINE)
    w.reload

    assert_equal w.online?, true
  end

  test 'online? - if offline' do
    w = default_website
    w.change_status!(Website::STATUS_OFFLINE)
    w.reload

    assert_equal w.online?, false
  end

  test 'offline? - if online' do
    w = default_website
    w.change_status!(Website::STATUS_ONLINE)
    w.reload

    assert_equal w.offline?, false
  end

  test 'offline? - if offline' do
    w = default_website
    w.change_status!(Website::STATUS_OFFLINE)
    w.reload

    assert_equal w.offline?, true
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
  test 'add location happy path' do
    website = default_website
    website.website_locations.destroy_all
    location = Location.find_by str_id: 'canada'

    website.add_location(location)

    website.reload
    website.website_locations.reload

    assert_equal website.website_locations[0].location.str_id, 'canada'
    assert_equal website.cloud_type, 'cloud'
  end

  test 'certs - provides when available' do
    website = default_website
    website.configs ||= {}
    website.configs['SSL_CERTIFICATE_PATH'] = 'cert/crt'
    website.configs['SSL_CERTIFICATE_KEY_PATH'] = 'cert/key'
    website.save!

    assert_equal website.certs, cert_path: "cert/crt", cert_key_path: "cert/key"
  end

  test 'certs - fail if SSL_CERTIFICATE_PATH not in site repo' do
    website = default_website
    website.configs ||= {}
    website.configs['SSL_CERTIFICATE_PATH'] = '../cert/crt'
    website.configs['SSL_CERTIFICATE_KEY_PATH'] = 'cert/key'
    website.save

    assert_equal website.valid?, false
  end

  test 'certs - fail if SSL_CERTIFICATE_KEY_PATH not in site repo' do
    website = default_website
    website.configs ||= {}
    website.configs['SSL_CERTIFICATE_PATH'] = 'cert/crt'
    website.configs['SSL_CERTIFICATE_KEY_PATH'] = '../cert/key'
    website.save

    assert_equal website.valid?, false
  end

  test 'certs - empty when not provided' do
    website = default_website
    website.configs = {}
    website.save!

    assert_equal website.certs.blank?, true
  end

  test 'certs - empty if empty strings' do
    website = default_website
    website.configs ||= {}
    website.configs['SSL_CERTIFICATE_PATH'] = ''
    website.configs['SSL_CERTIFICATE_KEY_PATH'] = ''
    website.save!

    assert_equal website.certs.blank?, true
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

  test 'can_deploy_to? should for open source even if no credit' do
    website = Website.find_by(site_name: 'testsite')
    website.open_source_activated = true
    website.open_source = {
      'status' => 'approved',
      'title' => 'helloworld',
      'description' => 'a ' * 31,
      'repository_url' => 'http://github.com/myrepo'
    }
    website.change_plan!(Website::OPEN_SOURCE_ACCOUNT_TYPE)
    website.user.credits = 0
    website.user.save!

    can_deploy, = website.can_deploy_to?(website.website_locations.first)
    assert_equal can_deploy, true
  end

  test 'can_deploy_to? should not be able to if open source but not activated' do
    website = Website.find_by(site_name: 'testsite')
    website.open_source_activated = false
    website.open_source = {
      'status' => 'approved',
      'title' => 'helloworld',
      'description' => 'a ' * 31,
      'repository_url' => 'http://github.com/myrepo'
    }
    website.change_plan!(Website::OPEN_SOURCE_ACCOUNT_TYPE)
    website.user.credits = 0
    website.user.save!

    can_deploy, = website.can_deploy_to?(website.website_locations.first)
    assert_equal can_deploy, false
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

  test "can_deploy_to? can't if too many concurrent deployments" do
    website = default_website

    (1..Deployment::MAX_CONCURRENT_BUILDS_PER_USER + 1).each do
      Deployment.create!(
        website: website,
        website_location: website.website_locations.first,
        status: Deployment::STATUS_RUNNING
      )
    end

    can_deploy, msg = website.can_deploy_to?(website.website_locations.first)

    assert_equal can_deploy, false
    assert_includes msg, 'Maximum number of concurrent'
  end

  test "can_deploy_to? can if on the limit with one not active temporally" do
    website = default_website

    (1..Deployment::MAX_CONCURRENT_BUILDS_PER_USER).each do
      Deployment.create!(
        website: website,
        website_location: website.website_locations.first,
        status: Deployment::STATUS_RUNNING
      )
      Task.create!(
        website: website,
        website_location: website.website_locations.first,
        status: Deployment::STATUS_RUNNING
      )
    end

    # this deployment is too old, so it's not counted.
    Deployment.create!(
      website: website,
      website_location: website.website_locations.first,
      status: Deployment::STATUS_RUNNING,
      created_at: (Deployment::MAX_RUN_TIME + 1.minute).ago
    )

    can_deploy, = website.can_deploy_to?(website.website_locations.first)

    assert_equal can_deploy, true
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

  test 'dotenv_filepath if set' do
    website = default_website
    website.configs ||= {}
    website.configs['DOTENV_FILEPATH'] = '.production.env'
    website.save!
    website.reload

    assert_equal website.dotenv_filepath, '.production.env'
  end

  test 'dotenv_filepath default' do
    website = default_website
    website.configs = {}
    website.save!
    website.reload

    assert_equal website.dotenv_filepath, '.env'
  end

  test 'dotenv filepath should be secure' do
    website = default_website
    website.configs ||= {}
    website.configs['DOTENV_FILEPATH'] = '../.production.env'
    website.save

    assert_equal website.valid?, false
  end

  test 'set config REFERENCE_WEBSITE_IMAGE - happy path' do
    referencing_to_website = Website.last

    website = default_website
    website.configs ||= {}
    website.configs['REFERENCE_WEBSITE_IMAGE'] = referencing_to_website.site_name
    website.save

    assert_equal website.valid?, true

    website.reload

    assert_equal website.reference_website_image, referencing_to_website
  end

  test 'set config REFERENCE_WEBSITE_IMAGE - fail if site not found' do
    website = default_website
    website.configs ||= {}
    website.configs['REFERENCE_WEBSITE_IMAGE'] = 'invalidsitename'
    website.save

    assert_equal website.valid?, false
  end

  test 'latest_reference_website_image_tag_address - happy path' do
    referencing_to_website = Website.last

    img_name_tag = 'my/image:1234'

    Deployment.create!(
      website: referencing_to_website,
      website_location: referencing_to_website.website_locations.first,
      status: Deployment::STATUS_RUNNING,
      obj: {
        image_name_tag: img_name_tag
      }
    )

    # should ignore this one even if it's the latest execution!
    Task.create!(
      website: referencing_to_website,
      website_location: referencing_to_website.website_locations.first,
      status: Deployment::STATUS_RUNNING,
      obj: {
        test: 'fail'
      }
    )

    website = default_website
    website.configs ||= {}
    website.configs['REFERENCE_WEBSITE_IMAGE'] = referencing_to_website.site_name
    website.save

    assert_equal website.valid?, true

    website.reload

    assert_equal website.latest_reference_website_image_tag_address, img_name_tag
  end

  test 'status_probe_path default' do
    website = default_website
    website.save!
    website.reload

    assert_equal website.status_probe_path, '/'
  end

  test 'status_probe_path custom' do
    website = default_website
    website.configs ||= {}
    website.configs['STATUS_PROBE_PATH'] = '/status'
    website.save!
    website.reload

    assert_equal website.status_probe_path, '/status'
  end

  test 'status_probe_path fail setting if invalid' do
    website = default_website
    website.configs ||= {}
    website.configs['STATUS_PROBE_PATH'] = '/sta\ntus'
    website.save

    assert_equal website.valid?, false
  end

  test 'status_probe_period default' do
    website = default_website

    assert_equal website.status_probe_period, 20
  end

  test 'status_probe_period custom' do
    website = default_website
    website.configs ||= {}
    website.configs['STATUS_PROBE_PERIOD'] = 30
    website.save!

    assert_equal website.status_probe_period, 30
  end

  test 'status_probe_period invalid value' do
    website = default_website
    website.configs ||= {}
    website.configs['STATUS_PROBE_PERIOD'] = 300
    website.save

    assert_equal website.valid?, false
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

  # spend credits
  test 'spend hourly credits - plan only' do
    website = default_website
    website.credit_actions.destroy_all
    wl = default_website_location
    wl.nb_cpus = 1
    wl.extra_storage = 0
    wl.save!

    website.spend_online_hourly_credits!

    plan = website.plan

    assert_equal website.credit_actions.reload.length, 1
    ca = website.credit_actions.first

    assert_equal(ca.credits_spent.to_f.round(4),
                 (plan[:cost_per_hour] * 100.0).to_f.round(4))
    assert_equal ca.action_type, CreditAction::TYPE_CONSUME_PLAN
  end

  test 'spend hourly credits - skip if open source' do
    website = default_website
    website.credit_actions.destroy_all
    wl = default_website_location
    wl.nb_cpus = 1
    wl.extra_storage = 0
    wl.save!

    website.open_source = sample_open_source_attributes
    website.account_type = Website::OPEN_SOURCE_ACCOUNT_TYPE
    website.open_source_activated = true
    website.save!

    website.spend_online_hourly_credits!

    assert_equal website.credit_actions.reload.length, 0
  end

  test 'spend hourly credits - not skip if open source and not activated' do
    website = default_website
    website.credit_actions.destroy_all
    wl = default_website_location
    wl.nb_cpus = 1
    wl.extra_storage = 0
    wl.save!

    website.open_source = sample_open_source_attributes
    website.account_type = Website::OPEN_SOURCE_ACCOUNT_TYPE
    website.open_source_activated = false
    website.save!

    website.spend_online_hourly_credits!
    website.reload
    puts "website.credit_actions #{website.credit_actions.inspect}"

    assert_equal website.credit_actions.length, 1
  end

  test 'spend hourly credits - with persistent services' do
    website = default_website
    website.credit_actions.destroy_all
    wl = default_website_location
    wl.nb_cpus = 1
    wl.extra_storage = 2
    wl.save!

    website.spend_persistence_hourly_credits!

    assert_equal website.credit_actions.reload.length, 1
    credits_actions = website.credit_actions

    assert_equal credits_actions[0].action_type, CreditAction::TYPE_CONSUME_STORAGE

    expected_credits_spent = Website.cost_price_to_credits(
      2 * CloudProvider::Kubernetes::COST_EXTRA_STORAGE_GB_PER_HOUR
    )
    assert_in_delta credits_actions[0].credits_spent, expected_credits_spent, 0.0000001
  end

  # spend_exceeding_traffic
  test 'spend_exceeding_traffic - happy path' do
    website = default_website
    website.credit_actions.destroy_all
    orig_credits = website.user.credits

    bytes = 5_000_000
    website.spend_exceeding_traffic!(bytes)

    c = CreditAction.last

    assert_equal c.action_type, 'consume-bandwidth'

    cost = 100 * CloudProvider::Helpers::Pricing.cost_for_extra_bandwidth_bytes(bytes)

    assert_equal c.credits_spent, cost
    assert_equal website.user.credits, orig_credits - cost
  end

  # plan
  test 'plan - happy path' do
    assert_equal default_website.plan[:id], '100-MB'
  end

  # memory
  test 'memory with 100 MB plan' do
    assert_equal default_website.account_type, "second"
    assert_equal default_website.memory, 100
  end

  # cpus
  test 'cpus without extra cpus' do
    assert_equal default_website.cpus, 1
  end

  test 'bandwidth_limit_in_bytes' do
    expected_limit = default_website.plan[:bandwidth] * 1000 * 1000 * 1000
    assert_equal default_website.bandwidth_limit_in_bytes, expected_limit
  end

  test 'cpus with extra cpus' do
    website = default_website
    wl = default_website_location
    wl.nb_cpus = 2
    wl.save!

    assert_equal website.cpus, 2
  end

  test 'exceeds_bandwidth_limit? - not exceeding' do
    assert_equal Website.exceeds_bandwidth_limit?(default_website, 10), false
  end

  test 'exceeds_bandwidth_limit? - exceeding' do
    consumed = default_website.bandwidth_limit_in_bytes + 10
    assert_equal Website.exceeds_bandwidth_limit?(default_website, consumed), true
  end

  # create website
  test 'create - should fail if empty' do
    website = Website.create({})

    assert_equal website.valid?, false
  end

  test 'create - subdomain' do
    user = default_user
    user.websites.destroy_all
    website = Website.create!(
      site_name: 'helloworld',
      user_id: user.id
    )

    assert_equal website.valid?, true
    assert_equal website.site_name, 'helloworld'
    assert_equal website.account_type, Website::DEFAULT_ACCOUNT_TYPE
    assert_equal website.domains, []
    assert_equal website.type, 'kubernetes'
  end

  test 'create - subdomain downcase if upper cases' do
    user = default_user
    user.websites.destroy_all
    website = Website.create!(
      site_name: 'helloWorld',
      user_id: user.id
    )

    assert_equal website.valid?, true
    assert_equal website.site_name, 'helloworld'
  end

  test 'create - subdomain where cannot create website' do
    user = default_user
    user.orders.destroy_all
    user.websites.destroy_all

    website = Website.create!(
      site_name: 'helloWorld',
      user_id: user.id
    )

    website2 = Website.create(
      site_name: 'helloworld2',
      user_id: user.id
    )

    assert_equal website.valid?, true
    assert_equal website2.valid?, false
  end

  test 'create - invalid account type' do
    user = default_user
    user.orders.destroy_all
    user.websites.destroy_all

    website = Website.create(
      site_name: 'helloWorld',
      user_id: user.id,
      account_type: 'second2'
    )

    assert_equal website.valid?, false
  end

  test 'create - custom domain' do
    user = default_user
    user.websites.destroy_all

    website = Website.create!(
      site_name: 'hello.World',
      user_id: user.id
    )

    assert_equal website.site_name, 'hello.world'
    assert_equal website.account_type, Website::DEFAULT_ACCOUNT_TYPE
    assert_equal website.domain_type, Website::DOMAIN_TYPE_CUSTOM_DOMAIN
    assert_equal website.domains, ['hello.world']
  end

  test 'create - custom domain - not allowed if root domain used' do
    user = User.first
    user.websites.destroy_all

    user2 = User.last
    user2.websites.destroy_all

    Website.create!(
      site_name: 'hello.World',
      user_id: user.id
    )

    website2 = Website.create(
      site_name: 'www.hello.World',
      user_id: user2.id
    )

    assert_equal website2.valid?, false
  end

  # # accessible_by

  test 'accessible_by? its own user' do
    website = Website.last

    assert_equal website.accessible_by?(website.user), true
  end

  test 'accessible_by? without access' do
    website = Website.last
    other_user = User.where('id != ?', website.user_id).first

    assert_equal other_user.id != website.user_id, true
    assert_equal website.accessible_by?(other_user), false
  end

  test "accessible_by? via collaborator" do
    user = User.find_by email: 'myadmin2@thisisit.com'
    user.is_admin = false
    user.save!

    assert_equal user.websites.map(&:site_name), ["www.what.is", "testsite2", "app.what.is"]

    assert_equal Website.find_by!(site_name: "testsite").accessible_by?(user), false

    new_website = Website.find_by site_name: "testsite"

    Collaborator.create!(
      user: user,
      website: new_website,
      permissions: [Website::PERMISSION_ROOT]
    )

    assert_equal Website.find_by!(site_name: "testsite").accessible_by?(user), true
  end

  test "accessible_by? with super admin" do
    Collaborator.all.each(&:destroy)
    u = default_user
    u.is_admin = true
    u.save!

    website_to_access = Website.where.not(user: u).first
    website_to_access.reload

    assert_equal website_to_access.accessible_by?(u), true
  end

  # change_plan!
  test "change_plan to open source - happy path" do
    w = default_website
    w.open_source = sample_open_source_attributes
    w.save

    w.change_plan!(Website::OPEN_SOURCE_ACCOUNT_TYPE)

    assert_equal w.account_type, Website::OPEN_SOURCE_ACCOUNT_TYPE
  end

  test "open source status - should change if already set" do
    w = default_website
    w.open_source = { status: Website::OPEN_SOURCE_STATUS_APPROVED }
    w.save!

    w.reload

    # change random field:
    w.configs = nil
    w.save!

    assert_equal w.open_source['status'], Website::OPEN_SOURCE_STATUS_APPROVED
  end

  test "open source status - should init to pending" do
    w = default_website
    w.account_type = Website::OPEN_SOURCE_ACCOUNT_TYPE
    orig_open_source = {
      title: 'helloworld',
      description: 'hellodesc ' * 40,
      repository_url: 'http://github.com/myrepo'
    }
    w.open_source = orig_open_source
    w.save!

    w.reload

    # change random field:
    w.configs = nil
    w.save!

    assert_equal w.open_source['status'], Website::OPEN_SOURCE_STATUS_PENDING
    assert_equal w.open_source['title'], orig_open_source[:title]
    assert_equal w.open_source['description'], orig_open_source[:description]
    assert_equal w.open_source['repository_url'], orig_open_source[:repository_url]
  end

  test "change_plan to open source - not enough words" do
    w = default_website
    w.open_source = {
      'status' => Website::OPEN_SOURCE_STATUS_APPROVED,
      'description' => " asdf " * 15,
      'repository_url' => "https://github.com/openode-io/openode-cli"
    }
    w.save

    assert_raise ActiveRecord::RecordInvalid do
      w.change_plan!(Website::OPEN_SOURCE_ACCOUNT_TYPE)
    end
  end

  test "change_plan to open source - invalid url" do
    w = default_website
    w.open_source = {
      'status' => Website::OPEN_SOURCE_STATUS_APPROVED,
      'description' => " asdf " * 200,
      'repository_url' => "ftp://github.com/openode-io/openode-cli"
    }
    w.save

    assert_raise ActiveRecord::RecordInvalid do
      w.change_plan!(Website::OPEN_SOURCE_ACCOUNT_TYPE)
    end
  end

  test "notify open source requested" do
    w = default_website

    w.open_source = {
      'status' => Website::OPEN_SOURCE_STATUS_APPROVED,
      'title' => 'helloworld',
      'description' => " asdf " * 200,
      'repository_url' => "http://github.com/openode-io/openode-cli"
    }

    w.account_type = Website::OPEN_SOURCE_ACCOUNT_TYPE

    w.save!

    mail_sent = ActionMailer::Base.deliveries.first
    assert_equal mail_sent.subject, 'Open source request'
    assert_includes mail_sent.body.raw_source, w.id.to_s
    assert_includes mail_sent.body.raw_source, w.site_name
    assert_includes mail_sent.body.raw_source, w.user.email
    assert_equal mail_sent.to, ['info@openode.io']
  end

  test "open source invalid due to missing back link" do
    w = default_website

    w.open_source = {
      'status' => Website::OPEN_SOURCE_STATUS_APPROVED,
      'title' => 'helloworld',
      'description' => " asdf " * 200,
      'repository_url' => "http://github.com/openode-io/openode-bad"
    }

    w.account_type = Website::OPEN_SOURCE_ACCOUNT_TYPE

    w.save

    assert_equal w.valid?, false
  end

  test "not notify open source requested if changing to non open source" do
    w = default_website

    w.open_source = {
      'status' => Website::OPEN_SOURCE_STATUS_APPROVED,
      'title' => 'helloworld',
      'description' => " asdf " * 200,
      'repository_url' => "http://github.com/openode-io/openode-cli"
    }

    w.account_type = Website::DEFAULT_ACCOUNT_TYPE

    w.save!

    mail_sent = ActionMailer::Base.deliveries.first
    assert_nil mail_sent
  end

  test "contains_open_source_backlink - if present" do
    result = Website.contains_open_source_backlink(
      "http://github.com/openode-io/openode-cli",
      "www.openode.io"
    )

    assert result
  end

  test "contains_open_source_backlink - if not present" do
    result = Website.contains_open_source_backlink(
      "http://github.com/openode-io/openode-bad",
      "www.openode.io"
    )

    assert_equal result, false
  end

  # active?
  test "active? - false if not online and no storage" do
    w = default_website
    wl = default_website_location
    wl.extra_storage = 0
    wl.save!

    w.change_status!(Website::STATUS_OFFLINE)

    assert_equal w.active?, false
  end

  test "active? - true if online and no storage" do
    w = default_website
    wl = default_website_location
    wl.extra_storage = 0
    wl.save!

    w.change_status!(Website::STATUS_ONLINE)

    assert_equal w.active?, true
  end

  test "active? - true if not online and with storage" do
    w = default_website
    wl = default_website_location
    wl.extra_storage = 1
    wl.save!

    w.change_status!(Website::STATUS_OFFLINE)

    assert_equal w.active?, true
  end

  test "active? - true if online and with storage" do
    w = default_website
    wl = default_website_location
    wl.extra_storage = 1
    wl.save!

    w.change_status!(Website::STATUS_ONLINE)

    assert_equal w.active?, true
  end

  # saving env variables
  test "env - retrieve without already stored ENV" do
    assert_equal default_website.env, {}
  end

  test "env - saving a single variable" do
    w = default_website
    w.save_secret!({ test: 1234 })
    w.store_env_variable!('MY_var', 'value1')

    assert_equal w.env.dig('MY_var'), 'value1'
    assert_equal w.secret[:test], 1234
  end

  test "env - saving variables multiple times" do
    w = default_website
    w.store_env_variable!('MY_var', 'value1')

    assert_equal w.env.dig('MY_var'), 'value1'

    w.reload
    w.store_env_variable!('MY_var2', 'value2')
    assert_equal w.env.dig('MY_var'), 'value1'
    assert_equal w.env.dig('MY_var2'), 'value2'
  end

  test "env - removing variable" do
    w = default_website
    w.save_secret!({ test: 1234 })
    w.store_env_variable!('MY_var', 'value1')
    w.store_env_variable!('MY_var2', 'value2')

    w.destroy_env_variable!('MY_var')

    assert_nil w.env.dig('MY_var')
    assert_equal w.env.dig('MY_var2'), 'value2'

    assert_equal w.secret[:test], 1234
  end
end
