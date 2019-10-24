class Website < ApplicationRecord
  serialize :domains, JSON
  serialize :configs, JSON
  serialize :dns, JSON
  serialize :storage_areas, JSON
  serialize :data, JSON

  self.inheritance_column = :_type

  belongs_to :user
  has_many :website_locations, dependent: :destroy
  has_many :events, foreign_key: :ref_id, class_name: :WebsiteEvent, dependent: :destroy
  has_many :snapshots
  has_many :deployments
  has_many :executions
  has_many :credit_actions

  scope :custom_domain, -> { where(domain_type: 'custom_domain') }

  REPOS_BASE_DIR = '/home/'

  STATUS_ONLINE = 'online'
  STATUS_OFFLINE = 'N/A'
  STATUS_STARTING = 'starting'
  STATUSES = [STATUS_ONLINE, STATUS_OFFLINE, STATUS_STARTING].freeze

  validates :site_name, presence: true
  validates :site_name, uniqueness: true
  validates :type, presence: true
  validates :domain_type, presence: true
  validates :cloud_type, presence: true

  validate :configs_must_comply
  validate :storage_areas_must_be_secure
  validate :validate_dns
  validate :validate_domains
  validate :validate_site_name

  validates :type, inclusion: { in: %w[nodejs docker] }
  validates :domain_type, inclusion: { in: %w[subdomain custom_domain] }
  validates :cloud_type, inclusion: { in: %w[cloud private-cloud] }
  validates :status, inclusion: { in: STATUSES }

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
    if location.str_id.include?('-') && domain_type != 'custom_domain'
      # to refactor (-)
      msg = 'This location is available only for custom domains for now (not subdomains). ' \
            'Only the following locations (ids) are available for subdomains: canada, usa, france.'
      raise ValidationError, msg
    end

    location_server = location.location_servers.first

    website_location = WebsiteLocation.create!(
      website: self,
      location: location,
      location_server: location_server
    )

    if location_server
      website_location.allocate_ports!
      website_location.update_remote_dns(with_auto_a: true)
    end
  end

  def remove_location(location)
    website_location = website_locations.to_a.find { |wl| wl.location_id == location.id }

    if website_location
      website_location.update_remote_dns(dns_entries: [])
      website_location.destroy
    end
  end

  def private_cloud?
    cloud_type == 'private-cloud'
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

  def validate_site_name
    errors.add(:site_name, 'Missing sitename') unless site_name
    return unless site_name

    send("validate_site_name_#{domain_type}")
  end

  def validate_site_name_subdomain
    errors.add(:site_name, 'The site name should not container a dot.') if site_name.include?('.')

    unless Website.domain_valid?("#{site_name}.openode.io")
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

  def plan
    plans = CloudProvider::Manager.instance.available_plans

    plans.find { |p| [p[:id], p[:internal_id]].include?(account_type) }
  end

  def free_sandbox?
    account_type == 'free'
  end

  def change_status!(new_status)
    logger.info("website #{site_name} changing status to #{new_status}")
    raise "Wrong status #{new_status}" unless STATUSES.include?(new_status)

    self.status = new_status
    save!
  end

  def change_plan!(account_type)
    logger.info("website #{site_name} changing plan to #{account_type}")
    self.account_type = account_type

    # to refactor
    self.cloud_type = account_type.include?('-') ? 'private-cloud' : 'cloud'

    save!
  end

  def online?
    status == STATUS_ONLINE
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

    unless user.credits?
      msg = 'No credit available. Please make sure to buy credits via the Administration ' \
            'dashboard in Billing - ' \
            "https://www.#{CloudProvider::Manager.instance.base_hostname}/admin/billing"
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
      total_extra_storage * CloudProvider::Internal::COST_EXTRA_STORAGE_GB_PER_HOUR
    )
  end

  def total_extra_cpus
    website_locations.sum { |wl| (wl.nb_cpus || 1) - 1 }
  end

  def extra_cpus_credits_cost_per_hour
    Website.cost_price_to_credits(
      total_extra_cpus * CloudProvider::Internal::COST_EXTRA_CPU_PER_HOUR
    )
  end

  def self.cost_price_to_credits(price)
    price * 100.0
  end

  # credits related task updates and calculations
  def spend_hourly_credits!
    current_plan = plan

    return unless current_plan

    spendings = [
      {
        action_type: CreditAction::TYPE_CONSUME_PLAN,
        credits_cost: Website.cost_price_to_credits(current_plan[:cost_per_hour])
      },
      {
        action_type: CreditAction::TYPE_CONSUME_STORAGE,
        credits_cost: extra_storage_credits_cost_per_hour
      },
      {
        action_type: CreditAction::TYPE_CONSUME_CPU,
        credits_cost: extra_cpus_credits_cost_per_hour
      }
    ]

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
