require 'uri'
require 'rest-client'

class Website < ApplicationRecord
  serialize :alerts, JSON
  serialize :domains, JSON
  serialize :open_source, JSON
  serialize :configs, JSON
  serialize :storage_areas, JSON
  serialize :data, JSON

  self.inheritance_column = :_type

  belongs_to :user
  has_many :collaborators, dependent: :destroy
  has_many :website_locations, dependent: :destroy
  has_many :snapshots, dependent: :destroy
  has_many :events, foreign_key: :ref_id, class_name: :WebsiteEvent, dependent: :destroy
  has_many :stop_events,
           foreign_key: :ref_id,
           class_name: :StopWebsiteEvent,
           dependent: :destroy
  has_many :notifications, class_name: :WebsiteNotification, dependent: :destroy
  has_many :executions, dependent: :destroy
  has_many :credit_actions
  has_many :website_bandwidth_daily_stats, foreign_key: :ref_id,
                                           class_name: :WebsiteBandwidthDailyStat,
                                           dependent: :destroy
  has_many :statuses, foreign_key: :ref_id,
                      class_name: :WebsiteStatus,
                      dependent: :destroy

  LIMIT_RAM_BLUE_GREEN_DEPLOYMENT = 1000

  # collaborators data plus user information
  def pretty_collaborators_h
    collaborators
      .includes(:user)
      .map do |c|
        current = c.attributes
        current['user'] = { id: c.user.id, email: c.user.email }
        current
      end
  end

  def deployments
    Deployment.type_dep.where(website: self)
  end

  scope :custom_domain, -> { where(domain_type: 'custom_domain') }
  scope :having_extra_storage, lambda {
    joins(:website_locations).where('website_locations.extra_storage > 0')
  }

  scope :in_statuses, lambda { |statuses|
    where(status: statuses)
  }

  REPOS_BASE_DIR = '/home/'

  STATUS_ONLINE = 'online'
  STATUS_OFFLINE = 'N/A'
  STATUS_STARTING = 'starting'
  STATUS_STOPPING = 'stopping'
  STATUSES = [STATUS_ONLINE, STATUS_OFFLINE, STATUS_STARTING, STATUS_STOPPING].freeze

  DEFAULT_STATUS = STATUS_OFFLINE

  DOMAIN_TYPE_SUBDOMAIN = 'subdomain'
  DOMAIN_TYPE_CUSTOM_DOMAIN = 'custom_domain'
  DOMAIN_TYPES = [DOMAIN_TYPE_SUBDOMAIN, DOMAIN_TYPE_CUSTOM_DOMAIN].freeze

  TYPE_DOCKER = 'docker'
  TYPE_KUBERNETES = 'kubernetes'
  TYPES = ['nodejs', TYPE_DOCKER, TYPE_KUBERNETES].freeze

  ALERT_STOP_LACK_CREDITS = 'stop_lacking_credits'
  ALERT_TYPES = [
    {
      id: ALERT_STOP_LACK_CREDITS,
      default: false
    }
  ]

  DEFAULT_ACCOUNT_TYPE = 'second'
  OPEN_SOURCE_ACCOUNT_TYPE = 'open_source'

  CLOUD_TYPE_PRIVATE_CLOUD = 'private-cloud'
  CLOUD_TYPE_CLOUD = 'cloud'

  PERMISSION_ROOT = 'root' # all permissions
  PERMISSION_DEPLOY = 'deploy'
  PERMISSION_ALIAS = 'alias'
  PERMISSION_STORAGE_AREA = 'storage_area'
  PERMISSION_LOCATION = 'location'
  PERMISSION_PLAN = 'plan'
  PERMISSION_CONFIG = 'config'

  PERMISSIONS = [
    PERMISSION_ROOT,
    PERMISSION_DEPLOY,
    PERMISSION_ALIAS,
    PERMISSION_STORAGE_AREA,
    PERMISSION_LOCATION,
    PERMISSION_PLAN,
    PERMISSION_CONFIG
  ].freeze

  OPEN_SOURCE_STATUS_APPROVED = 'approved'
  OPEN_SOURCE_STATUS_REJECTED = 'rejected'
  OPEN_SOURCE_STATUS_PENDING = 'pending'

  OPEN_SOURCE_STATUSES = [
    OPEN_SOURCE_STATUS_APPROVED,
    OPEN_SOURCE_STATUS_REJECTED,
    OPEN_SOURCE_STATUS_PENDING
  ].freeze

  CONFIG_VARIABLES = [
    {
      variable: 'SSL_CERTIFICATE_PATH',
      type: 'file_in_repo',
      description: 'Certificate file. Example: certs/mysite.crt'
    },
    {
      variable: 'SSL_CERTIFICATE_KEY_PATH',
      type: 'file_in_repo',
      description: 'Private key generated. Example: certs/privatekey.key'
    },
    {
      variable: 'REDIR_HTTP_TO_HTTPS',
      description: 'Will redirect HTTP traffic to HTTPS. A valid SSL cert is required.',
      type: 'website',
      enum: [true, false, 'true', 'false', ''],
      default: true
    },
    {
      variable: 'REPLICAS',
      description: 'Number of replicas of the given instance.',
      type: 'website_location',
      default: 1
    },
    {
      variable: 'TYPE',
      description: 'Deployment method (internal)',
      type: 'website',
      enum: [TYPE_KUBERNETES, TYPE_DOCKER]
    },
    {
      variable: 'MAX_BUILD_DURATION',
      description: 'The build duration limit in seconds.',
      min: 50,
      default: 100,
      max: 600
    },
    {
      variable: 'STATUS_PROBE_PATH',
      description: 'Status probe path called regularly to verify if the instance is healthy.',
      type: 'path',
      default: '/'
    },
    {
      variable: 'STATUS_PROBE_PERIOD',
      description: 'Interval where the STATUS_PROBE_PATH is checked.',
      min: 10,
      max: 60,
      default: 20
    },
    {
      variable: 'BLUE_GREEN_DEPLOYMENT',
      description: 'Avoid downtime while deploying, ' \
                    'temporarily keeps the old instance running while the new one is preparing.',
      type: 'blue_green_deployment',
      enum: [true, false, 'true', 'false', ''],
      default: false
    },
    {
      variable: 'SKIP_PORT_CHECK',
      description: 'Skip the port verification while deploying.',
      enum: ['true', 'false', '']
    },
    {
      variable: 'DOTENV_FILEPATH',
      type: 'file_in_repo',
      description: 'Relative dotenv (.env) file path. Example: .production.env',
      default: '.env'
    },
    {
      variable: 'REFERENCE_WEBSITE_IMAGE',
      type: 'site_name',
      description: 'Use the image of a specified website site name'
    }
  ].freeze

  before_validation :prepare_new_site, on: :create

  validates :user, presence: true
  validates :site_name, presence: true
  validates_uniqueness_of :site_name, case_sensitive: true
  validates :type, presence: true
  validates :domain_type, presence: true
  validates :cloud_type, presence: true

  validate :configs_must_comply
  validate :storage_areas_must_be_secure
  validate :validate_domains
  validate :validate_site_name
  validate :validate_account_type
  validate :validate_alerts

  with_options if: :open_source_plan? do
    before_validation :force_open_source_status_pending_on_create, on: :create
    before_validation :ensure_open_source_status

    validates :open_source, presence: true
    validate :validate_open_source
  end

  validate :can_create_new_site, on: :create
  validate :can_use_root_domain, on: :create

  validates :type, inclusion: { in: TYPES }
  validates :domain_type, inclusion: { in: DOMAIN_TYPES }
  validates :cloud_type, inclusion: { in: [CLOUD_TYPE_PRIVATE_CLOUD, CLOUD_TYPE_CLOUD] }
  validates :status, inclusion: { in: STATUSES }

  after_save :notify_open_source_requested

  def init_subdomain; end

  def init_custom_domain
    self.domains ||= []

    self.domains.unshift(site_name)

    self.domains = domains.uniq
  end

  def can_create_new_site
    if user && !user.can_create_new_website?
      errors.add(:invalid, 'Number of websites limit reached for a free user.')
    end
  end

  def accessible_by?(current_user)
    website_ids_with_access = current_user.websites_with_access.pluck(:id)

    website_ids_with_access.include?(id) || !current_user.is_admin.zero?
  end

  def open_source_approved?
    open_source.present? && open_source['status'] == 'approved'
  end

  def open_source_plan?
    account_type == OPEN_SOURCE_ACCOUNT_TYPE
  end

  def self.initial_alerts
    ALERT_TYPES
      .select { |alert_type| alert_type[:default] }
      .map { |alert_type| alert_type[:id] }
  end

  def self.strip_non_host_site_name_parts(site_name)
    if !site_name.starts_with?('http://') && !site_name.starts_with?('https://')
      return site_name
    end

    uri = URI(site_name)

    uri.host
  end

  def prepare_new_site
    return unless site_name

    self.account_type ||= DEFAULT_ACCOUNT_TYPE
    self.account_type = DEFAULT_ACCOUNT_TYPE if self.account_type == 'free'
    change_plan(account_type)

    self.status ||= DEFAULT_STATUS
    change_status(status)

    self.site_name = Website.strip_non_host_site_name_parts(site_name.downcase)
    self.domain_type = DOMAIN_TYPE_SUBDOMAIN
    self.type = TYPE_KUBERNETES
    self.redir_http_to_https = false
    self.instance_type = 'server' # to deprecate
    self.open_source ||= {}
    self.domains = []
    self.alerts = Website.initial_alerts

    if site_name.include?('.')
      self.domain_type = DOMAIN_TYPE_CUSTOM_DOMAIN
      domains << Website.clean_domain(site_name)
    end

    if site_name.include?(".#{CloudProvider::Manager.base_hostname}")
      self.domain_type = DOMAIN_TYPE_SUBDOMAIN
      self.site_name = site_name.split(".#{CloudProvider::Manager.base_hostname}").first
    end

    send("init_#{domain_type}")
  end

  def locations
    website_locations.map(&:location)
  end

  def location_exists?(str_id)
    locations.to_a.any? { |location| location.str_id == str_id }
  end

  def create_event(obj)
    stripped_obj = Str::Encode.strip_invalid_chars(obj, encoding: 'ASCII')

    website_event = WebsiteEvent.create(ref_id: id, obj: stripped_obj)

    WebsiteEventsChannel.broadcast_to(
      WebsiteEventsChannel.id_channel(self),
      website_event
    )
  rescue StandardError => e
    Rails.logger.error(e)
  end

  def add_location(location)
    location_server = location.location_servers.first

    WebsiteLocation.create!(
      website: self,
      location: location,
      location_server: location_server
    )

    self.cloud_type = CLOUD_TYPE_CLOUD
    save!
  end

  def remove_location(location)
    website_location = website_locations.to_a.find { |wl| wl.location_id == location.id }

    website_location&.destroy
  end

  def configs_must_comply
    self.configs ||= {}

    self.configs.each do |var_name, value|
      config = Website.config_def(var_name)

      next unless config

      if config[:enum] && !config[:enum].include?(value)
        errors.add(:configs, "Invalid value, valid ones: #{config[:enum]}")
      end

      if config[:min] && config[:max]
        parsed_val = value.to_f

        unless parsed_val.present? && parsed_val >= config[:min] &&
               parsed_val <= config[:max]
          errors.add(:configs, "Invalid value, , min = #{config[:min]}, max = #{config[:max]}")
        end
      end

      if %w[blue_green_deployment boolean].include?(config[:type])
        self.configs[var_name] = [true, 'true'].include?(value)
      end

      if value.present? && config[:type].present?
        # call method based on type type, see below
        send("config_#{config[:type]}_must_comply", config, self.configs[var_name])
      end
    end
  end

  def config_blue_green_deployment_must_comply(_config, value)
    if value && plan[:ram] > LIMIT_RAM_BLUE_GREEN_DEPLOYMENT
      errors.add(:configs, "Maximum RAM with blue green deployment is " \
                            "#{LIMIT_RAM_BLUE_GREEN_DEPLOYMENT} MB")
    end
  end

  def config_path_must_comply(_config, value)
    unless Io::Path.valid?(value)
      errors.add(:configs, "Invalid config value")
    end
  end

  def config_file_in_repo_must_comply(_config, value)
    cur_dir = "#{repo_dir}#{value}"

    unless Io::Path.secure?(repo_dir, cur_dir)
      errors.add(:configs, "Invalid config value")
    end
  end

  def config_website_must_comply(config, value)
    # is setting an attribute in website object
    self[config[:variable].downcase] = value
  end

  def config_website_location_must_comply(config, value)
    # is setting an attribute in first website_location object
    wl = website_locations.first

    if wl
      # set the field only if it exists
      wl[config[:variable].downcase] = value
      wl.save!
    end
  end

  def config_site_name_must_comply(_config, value)
    unless user.websites_with_access.any? { |w| w.site_name == value }
      errors.add(:configs, "Unauthorized access to #{value} from #{site_name}")
    end

    unless Website.exists?(site_name: value)
      errors.add(:configs, "website #{value} not found")
    end
  end

  def storage_areas_must_be_secure
    self.storage_areas ||= []

    self.storage_areas.each do |storage_area|
      cur_dir = "#{repo_dir}#{storage_area}"

      unless Io::Path.secure?(repo_dir, cur_dir)
        errors.add(:storage_areas, "Invalid storage area path #{cur_dir}")
      end
    end
  end

  def subdomain?
    domain_type == DOMAIN_TYPE_SUBDOMAIN
  end

  def custom_domain?
    domain_type == DOMAIN_TYPE_CUSTOM_DOMAIN
  end

  def can_use_root_domain
    # verify that the root domain is not already used by another user
    root_domain = WebsiteLocation.root_domain(site_name)
    root_domain_website = Website.find_by(site_name: root_domain)

    if root_domain_website && root_domain_website.user_id != user_id
      errors.add(:site_name, 'Root domain already used')
    end
  end

  def validate_site_name
    errors.add(:site_name, 'Missing sitename') unless site_name
    return unless site_name

    send("validate_site_name_#{domain_type}")
  end

  def validate_site_name_subdomain
    errors.add(:site_name, 'The site name should not container a dot.') if site_name.include?('.')

    unless Website.domain_valid?("#{site_name}.#{CloudProvider::Manager.base_hostname}")
      errors.add(:site_name, "Invalid subdomain #{site_name}")
    end
  end

  def validate_site_name_custom_domain
    errors.add(:site_name, "Invalid domain #{site_name}") unless Website.domain_valid?(site_name)
  end

  def self.domain_valid?(domain)
    (domain =~ %r{^[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,10}(:[0-9]{1,5})?(/.*)?$})
      .andand.zero?
  end

  def self.clean_domain(domain)
    domain.downcase.strip
  end

  def validate_domains
    return if domain_type == 'subdomain'

    self.domains ||= []

    self.domains.each do |domain|
      errors.add(:domains, "Invalid alias (#{domain}) format") unless Website.domain_valid?(domain)

      unless domain.include?(site_name)
        errors.add(:domains, "Invalid alias (#{domain}), must be a subdomain of #{site_name}")
      end
    end
  end

  MAX_RAM_PLAN_WITHOUT_PAID_ORDER = 100

  def validate_alerts
    current_alerts.each do |alert|
      unless ALERT_TYPES.map { |a| a[:id] }.include?(alert)
        errors.add(:alerts, "Invalid alert #{alert}")
      end
    end
  end

  def validate_account_type
    found_plan = Website.plan_of(account_type)
    return errors.add(:account_type, "Invalid plan #{account_type}") unless found_plan

    if found_plan.dig(:ram) &&
       found_plan[:ram] > MAX_RAM_PLAN_WITHOUT_PAID_ORDER && !user.orders?
      errors.add(:account_type,
                 "Maximum available plan without a paid order is " \
                 "#{MAX_RAM_PLAN_WITHOUT_PAID_ORDER} MB RAM.")
    end
  end

  def force_open_source_status_pending_on_create
    self.open_source ||= {}
    self.open_source['status'] = OPEN_SOURCE_STATUS_PENDING
  end

  def ensure_open_source_status
    cpy_previous_open_source = open_source_was

    cpy_previous_open_source ||= {}
    self.open_source ||= {}

    if !open_source['status'] && !cpy_previous_open_source['status']
      self.open_source['status'] = OPEN_SOURCE_STATUS_PENDING
    end
  end

  def self.contains_open_source_backlink(repo_url, required_str)
    content_repo_readme = RestClient::Request.execute(method: :get, url: repo_url)

    content_repo_readme.to_s.include?(required_str)
  rescue StandardError => e
    logger.error("Error verifying contains open source backlink, #{e}")
    false
  end

  def validate_open_source
    return if open_source['status'] == OPEN_SOURCE_STATUS_REJECTED

    # status
    open_source['status'] ||= OPEN_SOURCE_STATUS_PENDING

    unless OPEN_SOURCE_STATUSES.include?(open_source['status'])
      errors.add(:open_source, "invalid open source status (#{open_source['status']})")
    end

    # title
    if !open_source['title'] || open_source['title'].length < 7
      errors.add(:open_source, "provide a project title")
    end

    # description
    min_description_words = 30

    description_words = open_source['description']&.scan(/\w+/)

    if !description_words || description_words.size < min_description_words
      errors.add(:open_source, "provide at least #{min_description_words} words description")
    end

    # url
    unless open_source['repository_url'] =~ /\A#{URI::DEFAULT_PARSER.make_regexp(%w[http https])}\z/
      errors.add(:open_source, "invalid repository URL")
    end

    # then url must contain www.openode.io
    if !open_source_activated &&
       !Website.contains_open_source_backlink(open_source['repository_url'],
                                              "www.openode.io")
      errors.add(:open_source, "missing thanks link www.openode.io")
    end

    errors.count.zero?
  end

  def notify_open_source_requested
    return if saved_changes['account_type'].blank?
    return if saved_changes['account_type'][1] != Website::OPEN_SOURCE_ACCOUNT_TYPE

    SupportMailer.with(
      title: 'Open source request',
      attributes: {
        website_id: id,
        site_name: site_name,
        user: user.inspect
      }
    ).contact.deliver_now
  end

  def self.config_def(var_name)
    Website::CONFIG_VARIABLES.find { |c| c[:variable] == var_name }
  end

  def self.valid_config_variable?(var_name)
    Website::CONFIG_VARIABLES
      .map { |var| var[:variable] }
      .include? var_name
  end

  def skip_port_check?
    configs && [true, 'true'].include?(configs['SKIP_PORT_CHECK'])
  end

  def certs
    if configs && configs['SSL_CERTIFICATE_PATH'].present? &&
       configs['SSL_CERTIFICATE_KEY_PATH'].present?
      {
        cert_path: configs['SSL_CERTIFICATE_PATH'],
        cert_key_path: configs['SSL_CERTIFICATE_KEY_PATH']
      }
    end
  end

  def current_alerts
    alerts || []
  end

  def alerting?(alert_type)
    current_alerts.include?(alert_type)
  end

  def max_build_duration
    [
      (configs['MAX_BUILD_DURATION'] || Website.config_def('MAX_BUILD_DURATION')[:default]).to_i,
      Website.config_def('MAX_BUILD_DURATION')[:max]
    ]
      .min
  end

  def get_config(config_name)
    self.configs ||= {}
    configs[config_name] || Website.config_def(config_name)[:default]
  end

  def dotenv_filepath
    get_config("DOTENV_FILEPATH")
  end

  def blue_green_deployment?
    get_config("BLUE_GREEN_DEPLOYMENT")
  end

  def reference_website_image
    Website.find_by(site_name: get_config("REFERENCE_WEBSITE_IMAGE"))
  end

  def latest_reference_website_image_deployment
    reference_website_image&.deployments&.last
  end

  def latest_reference_website_image_tag_address
    latest_reference_website_image_deployment&.obj&.dig('image_name_tag')
  end

  # ENV stored in the db
  def env
    ((secret || {}).dig(:env) || {})
      .stringify_keys
  end

  def overwrite_env_variables!(variables)
    merge_secret!(env: variables)

    env
  end

  def update_env_variables!(variables)
    current_env_variables = env
    current_env_variables.merge!(variables)
    merge_secret!(env: current_env_variables)

    env
  end

  def store_env_variable!(variable, value)
    current_env_variables = env
    current_env_variables[variable] = value
    merge_secret!(env: current_env_variables)

    env
  end

  def destroy_env_variable!(variable)
    current_env_variables = env
    current_env_variables.delete(variable)
    merge_secret!(env: current_env_variables)

    env
  end

  def status_probe_path
    get_config("STATUS_PROBE_PATH")
  end

  def status_probe_period
    get_config("STATUS_PROBE_PERIOD")
  end

  def repo_dir
    return '/invalid/repository/' if !user_id || !site_name

    "#{Website::REPOS_BASE_DIR}#{user_id}/#{site_name}/"
  end

  def self.plan_of(acc_type)
    plans = CloudProvider::Manager.instance.available_plans

    plans.find { |p| [p[:id], p[:internal_id]].include?(acc_type) }
  end

  def plan
    Website.plan_of(account_type)
  end

  def memory
    plan[:ram].to_i # must not have decimals
  end

  def cpus
    (1 + total_extra_cpus).to_i
  end

  def bandwidth_limit_in_bytes
    # original is in Gb
    plan[:bandwidth].to_i * 1000 * 1000 * 1000
  end

  def plan_name
    "#{plan[:ram]} MB"
  rescue StandardError
    "N/A"
  end

  def self.exceeds_bandwidth_limit?(website, bytes_consumed)
    bytes_consumed > website.bandwidth_limit_in_bytes
  end

  def price
    ("%.2f" % plan[:cost_per_month].to_d.truncate(2))
  rescue StandardError
    "N/A"
  end

  def first_ip
    website_locations.first.location_server.ip
  rescue StandardError
    "N/A"
  end

  def change_status!(new_status, args = {})
    change_status(new_status)

    if args[:skip_validations]
      save(validate: false)
    else
      save!
    end
  end

  def change_status(new_status)
    logger.info("website #{site_name} changing status to #{new_status}")
    raise "Wrong status #{new_status}" unless STATUSES.include?(new_status)

    self.status = new_status
  end

  def recent_out_of_memory_detected?
    statuses.last&.simplified_container_statuses.to_s.downcase.include?('oomkilled')
  end

  def init_change_plan_to_open_source
    self.open_source['status'] = OPEN_SOURCE_STATUS_PENDING

    if open_source['title'].blank?
      self.open_source['title'] = 'title here'
    end

    if open_source['description'].blank?
      self.open_source['description'] = 'Description ' * 31
    end

    if open_source['repository_url'].blank?
      self.open_source['repository_url'] = 'https://repourl.com'
    end
  end

  def change_plan(acc_type)
    logger.info("website #{site_name} changing plan to #{acc_type}")
    self.account_type = acc_type

    init_change_plan_to_open_source if open_source_plan?

    self.cloud_type = 'cloud'
  end

  def change_plan!(acc_type)
    change_plan(acc_type)

    save!
  end

  def online?
    status == STATUS_ONLINE
  end

  def stopping?
    status == STATUS_STOPPING
  end

  def offline?
    status == STATUS_OFFLINE
  end

  def first_location
    website_locations.first&.location
  end

  def add_storage_area(storage_area)
    self.storage_areas ||= []
    self.storage_areas << storage_area
    self.storage_areas = self.storage_areas.uniq
  end

  def remove_storage_area(storage_area)
    self.storage_areas ||= []
    self.storage_areas.delete(storage_area)
  end

  # true/false, msg
  def can_deploy_to?(_website_location)
    unless user.activated?
      msg = 'User account not yet activated. Please make sure to click the ' \
            'activation link in your registration email.'
      return false, "*** #{msg}"
    end

    return false, '*** User suspended' if user.suspended?

    if open_source_plan? && open_source_activated
      return true, ''
    end

    unless user.credits?(Website.cost_price_to_credits(plan[:cost_per_hour]))
      msg = 'No credit available. Please make sure to buy credits via the Administration ' \
            'dashboard in Billing - ' \
            "https://www.#{CloudProvider::Manager.base_hostname}/admin/billing"
      return false, "*** #{msg}"
    end

    nb_active_deployments = Deployment.type_dep.running.by_user(user).active.count

    if nb_active_deployments > Deployment::MAX_CONCURRENT_BUILDS_PER_USER
      return false, "*** Maximum number of concurrent builds per user reached."
    end

    [true, '']
  end

  def total_extra_storage
    website_locations.sum { |wl| wl.extra_storage || 0 }
  end

  def extra_storage?
    total_extra_storage.positive?
  end

  def extra_storage_credits_cost_per_hour
    Website.cost_price_to_credits(
      total_extra_storage * CloudProvider::Kubernetes::COST_EXTRA_STORAGE_GB_PER_HOUR
    )
  end

  def active?
    extra_storage? || online?
  end

  def total_extra_cpus
    website_locations.sum { |wl| (wl.nb_cpus || 1) - 1 }
  end

  def self.cost_price_to_credits(price)
    price * 100.0
  end

  def plan_cost
    Website.cost_price_to_credits(plan[:cost_per_hour]) *
      (website_locations.first&.replicas || 1)
  end

  def blue_green_deployment_option_cost
    pricing_params = CloudProvider::Manager.instance.application.dig('pricing')
    cost_ratio = pricing_params.dig('blue_green_ratio_plan_cost').to_f

    Website.cost_price_to_credits(plan[:cost_per_hour]) * cost_ratio *
      (website_locations.first&.replicas || 1)
  end

  # credits related task updates and calculations
  def spend_online_hourly_credits!(hourly_ratio = 1.0)
    return unless plan

    spendings = [
      {
        action_type: CreditAction::TYPE_CONSUME_PLAN,
        credits_cost: plan_cost * hourly_ratio
      }
    ]

    if blue_green_deployment?

      spendings << {
        action_type: CreditAction::TYPE_CONSUME_BLUE_GREEN,
        credits_cost: blue_green_deployment_option_cost * hourly_ratio
      }
    end

    spend_hourly_credits!(spendings)
  end

  # minutes ratio of the current hour.
  # if it's now 12:30 (to_time), and from time is 12:00 the ratio is 0.5
  def self.last_time_elapsed_hour_ratio(from_time, to_time)
    [((to_time - from_time) / (60.60 * 60.0)), 1].min
  end

  def spending_partial_hourly_ratio
    # take max time betwee last deployment and current time
    from_time = [deployments.completed.last&.created_at, Time.zone.now.beginning_of_hour]
                .select(&:present?)
                .max

    to_time = Time.zone.now

    # min 0, max 1
    [
      [Website.last_time_elapsed_hour_ratio(from_time, to_time), 0].max,
      1
    ].min
  end

  def spend_partial_last_hour_credits
    hourly_ratio = spending_partial_hourly_ratio

    spend_online_hourly_credits!(hourly_ratio)
  rescue StandardError => e
    logger.info("Issue spend_partial_last_hour_credits #{e.inspect}")
  end

  def spend_persistence_hourly_credits!
    spendings = [
      {
        action_type: CreditAction::TYPE_CONSUME_STORAGE,
        credits_cost: extra_storage_credits_cost_per_hour
      }
    ]

    spend_hourly_credits!(spendings)
  end

  def spend_hourly_credits!(spendings)
    current_plan = plan

    return if !current_plan || (open_source_plan? && open_source_activated)

    consume_spendings(spendings)
  end

  def spend_exceeding_traffic!(bytes)
    spendings = [
      {
        action_type: CreditAction::TYPE_CONSUME_BANDWIDTH,
        credits_cost: Website.cost_price_to_credits(
          CloudProvider::Helpers::Pricing.cost_for_extra_bandwidth_bytes(bytes)
        )
      }
    ]

    consume_spendings(spendings)
  end

  def consume_spendings(spendings)
    spendings.each do |spending|
      if spending[:credits_cost] != 0
        CreditAction.consume!(self, spending[:action_type],
                              spending[:credits_cost], with_user_update: true)
      end
    end
  end

  def normalized_storage_areas
    site_dir = repo_dir

    (self.storage_areas || []).map do |storage_area|
      (site_dir + storage_area)
        .gsub('//', '/')
        .gsub(site_dir, './')
        .gsub('././', './')
        .gsub('//', '/')
    end
  rescue StandardError => e
    logger.info("Issue normalizing storage areas #{e.inspect}")
    []
  end
end
