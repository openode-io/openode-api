require 'uri'

class Website < ApplicationRecord
  serialize :domains, JSON
  serialize :open_source, JSON
  serialize :configs, JSON
  serialize :dns, JSON
  serialize :storage_areas, JSON
  serialize :data, JSON

  self.inheritance_column = :_type

  belongs_to :user
  has_many :collaborators
  has_many :website_locations, dependent: :destroy
  has_many :events, foreign_key: :ref_id, class_name: :WebsiteEvent, dependent: :destroy
  has_many :deployments
  has_many :executions
  has_many :credit_actions
  has_many :website_bandwidth_daily_stats, foreign_key: :ref_id,
                                           class_name: :WebsiteBandwidthDailyStat,
                                           dependent: :destroy
  has_many :website_utilization_logs, foreign_key: :ref_id,
                                      class_name: :WebsiteUtilizationLog,
                                      dependent: :destroy

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
  STATUSES = [STATUS_ONLINE, STATUS_OFFLINE, STATUS_STARTING].freeze

  DEFAULT_STATUS = STATUS_OFFLINE

  DOMAIN_TYPE_SUBDOMAIN = 'subdomain'
  DOMAIN_TYPE_CUSTOM_DOMAIN = 'custom_domain'
  DOMAIN_TYPES = [DOMAIN_TYPE_SUBDOMAIN, DOMAIN_TYPE_CUSTOM_DOMAIN].freeze

  TYPE_DOCKER = 'docker'
  TYPE_KUBERNETES = 'kubernetes'
  TYPES = ['nodejs', TYPE_DOCKER, TYPE_KUBERNETES].freeze

  DEFAULT_ACCOUNT_TYPE = 'free'
  OPEN_SOURCE_ACCOUNT_TYPE = 'open_source'

  CLOUD_TYPE_PRIVATE_CLOUD = 'private-cloud'
  CLOUD_TYPE_CLOUD = 'cloud'

  PERMISSION_ROOT = 'root' # all permissions
  PERMISSION_DEPLOY = 'deploy'
  PERMISSION_DNS = 'dns'
  PERMISSION_ALIAS = 'alias'
  PERMISSION_STORAGE_AREA = 'storage_area'
  PERMISSION_LOCATION = 'location'
  PERMISSION_PLAN = 'plan'
  PERMISSION_CONFIG = 'config'

  PERMISSIONS = [
    PERMISSION_ROOT,
    PERMISSION_DEPLOY,
    PERMISSION_DNS,
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

  validates :user, presence: true
  validates :site_name, presence: true
  validates_uniqueness_of :site_name, case_sensitive: true
  validates :type, presence: true
  validates :domain_type, presence: true
  validates :cloud_type, presence: true

  validate :configs_must_comply
  validate :storage_areas_must_be_secure
  validate :validate_dns
  validate :validate_domains
  validate :validate_site_name
  validate :validate_account_type

  with_options if: :open_source_plan? do
    validates :open_source, presence: true
    validate :validate_open_source
  end

  validate :can_create_new_site, on: :create
  validate :can_use_root_domain, on: :create

  validates :type, inclusion: { in: TYPES }
  validates :domain_type, inclusion: { in: DOMAIN_TYPES }
  validates :cloud_type, inclusion: { in: [CLOUD_TYPE_PRIVATE_CLOUD, CLOUD_TYPE_CLOUD] }
  validates :status, inclusion: { in: STATUSES }

  before_validation :prepare_new_site, on: :create

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

    website_ids_with_access.include?(id)
  end

  def open_source_approved?
    open_source.present? && open_source['status'] == 'approved'
  end

  def open_source_plan?
    account_type == OPEN_SOURCE_ACCOUNT_TYPE
  end

  def prepare_new_site
    return unless site_name

    self.account_type ||= DEFAULT_ACCOUNT_TYPE
    change_plan(account_type)

    self.status ||= DEFAULT_STATUS
    change_status(status)

    self.site_name = site_name.downcase
    self.domain_type = DOMAIN_TYPE_SUBDOMAIN
    self.type = TYPE_KUBERNETES
    self.redir_http_to_https = false
    self.instance_type = 'server' # to deprecate
    self.open_source = { 'status' => 'active' }
    self.domains = []

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
    WebsiteEvent.create(ref_id: id, obj: obj)
  end

  def add_location(location)
    location_server = location.location_servers.first

    website_location = WebsiteLocation.create!(
      website: self,
      location: location,
      location_server: location_server
    )

    if location_server && type != TYPE_KUBERNETES
      website_location.update_remote_dns(with_auto_a: true)
    end

    self.cloud_type = CLOUD_TYPE_CLOUD
    save!
  end

  def remove_location(location)
    website_location = website_locations.to_a.find { |wl| wl.location_id == location.id }

    if website_location
      if type != TYPE_KUBERNETES
        website_location.update_remote_dns(dns_entries: [])
      end

      website_location.destroy
    end
  end

  def configs_must_comply
    self.configs ||= {}

    self.configs.each do |var_name, value|
      config = Website.config_def(var_name)

      next unless config

      if config[:enum] && !config[:enum].include?(value)
        errors.add(:configs, "Invalid value, valid ones: #{config[:enum]}")
      end

      next unless config[:min] && config[:max]

      parsed_val = value.to_f

      unless parsed_val.present? && parsed_val >= config[:min] &&
             parsed_val <= config[:max]
        errors.add(:configs, "Invalid value, , min = #{config[:min]}, max = #{config[:max]}")
      end
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

  def validate_dns
    return if domain_type == 'subdomain'

    self.dns ||= []

    self.dns.each do |dns_entry|
      unless domains.include?(dns_entry['domainName'])
        errors.add(:dns, "Invalid domain (#{dns_entry['domainName']}), " \
                          "available domains: #{domains.inspect}")
      end

      valid_types = %w[
        A CNAME TXT AAAA MX CAA NS SRV SSHFP TXT
      ]

      unless valid_types.include?(dns_entry['type'])
        errors.add(:dns, "Invalid type (#{dns_entry['type']}), " \
                          "available types: #{valid_types.inspect}")
      end
    end
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
    (domain =~ %r{^[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,6}(:[0-9]{1,5})?(/.*)?$})
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

  def validate_account_type
    found_plan = Website.plan_of(account_type)
    errors.add(:account_type, "Invalid plan #{account_type}") unless found_plan
  end

  def validate_open_source
    self.open_source ||= {}

    unless open_source['status']
      self.open_source['status'] = OPEN_SOURCE_STATUS_PENDING
    end

    # status
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
    unless open_source['repository_url'] =~ /\A#{URI.regexp(%w[http https])}\z/
      errors.add(:open_source, "invalid repository URL")
    end
  end

  CONFIG_VARIABLES = [
    {
      variable: 'SSL_CERTIFICATE_PATH',
      description: 'Certificate file. Example: certs/mysite.crt'
    },
    {
      variable: 'SSL_CERTIFICATE_KEY_PATH',
      description: 'Private key generated. Example: certs/privatekey.key'
    },
    {
      variable: 'REDIR_HTTP_TO_HTTPS',
      description: 'Will redirect HTTP traffic to HTTPS. An HTTPS server is required.',
      type: 'website',
      enum: ['true', 'false', '']
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
      variable: 'SKIP_PORT_CHECK',
      description: 'Skip the port verification while deploying.',
      enum: ['true', 'false', '']
    }
  ].freeze

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

  def max_build_duration
    [
      (configs['MAX_BUILD_DURATION'] || Website.config_def('MAX_BUILD_DURATION')[:default]).to_i,
      Website.config_def('MAX_BUILD_DURATION')[:max]
    ]
      .min
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

  def plan_name
    "#{plan[:ram]} MB"
  rescue StandardError
    "N/A"
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

  def free_sandbox?
    account_type == 'free'
  end

  def change_status!(new_status)
    change_status(new_status)

    save!
  end

  def change_status(new_status)
    logger.info("website #{site_name} changing status to #{new_status}")
    raise "Wrong status #{new_status}" unless STATUSES.include?(new_status)

    self.status = new_status
  end

  def change_plan(acc_type)
    logger.info("website #{site_name} changing plan to #{acc_type}")
    self.account_type = acc_type

    self.open_source = open_source || {}
    self.open_source['status'] ||= OPEN_SOURCE_STATUS_PENDING

    if open_source['title'].blank?
      self.open_source['title'] = 'title here'
    end

    if open_source['description'].blank?
      self.open_source['description'] = 'Description ' * 31
    end

    if open_source['repository_url'].blank?
      self.open_source['repository_url'] = 'https://repourl.com'
    end

    self.cloud_type = 'cloud'
  end

  def change_plan!(acc_type)
    change_plan(acc_type)

    save!
  end

  def online?
    status == STATUS_ONLINE
  end

  def offline?
    status == STATUS_OFFLINE
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

  def remove_dns_entry(entry)
    self.dns ||= []

    entry_found = self.dns.find do |d|
      d['domainName'] == entry['domainName'] &&
        d['type'] == entry['type'] &&
        d['value'] == entry['value']
    end

    self.dns.delete(entry_found) if entry_found
  end

  # true/false, msg
  def can_deploy_to?(_website_location)
    unless user.activated?
      msg = 'User account not yet activated. Please make sure to click the ' \
            'activation link in your registration email.'
      return false, "*** #{msg}"
    end

    return false, '*** User suspended' if user.suspended?

    if !user.credits? && !open_source_plan?
      msg = 'No credit available. Please make sure to buy credits via the Administration ' \
            'dashboard in Billing - ' \
            "https://www.#{CloudProvider::Manager.base_hostname}/admin/billing"
      return false, "*** #{msg}"
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

  def total_extra_cpus
    website_locations.sum { |wl| (wl.nb_cpus || 1) - 1 }
  end

  def self.cost_price_to_credits(price)
    price * 100.0
  end

  # credits related task updates and calculations
  def spend_online_hourly_credits!
    current_plan = plan

    return unless current_plan

    spendings = [
      {
        action_type: CreditAction::TYPE_CONSUME_PLAN,
        credits_cost: Website.cost_price_to_credits(current_plan[:cost_per_hour])
      }
    ]

    spend_hourly_credits!(spendings)
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

    return if !current_plan || open_source_plan?

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
