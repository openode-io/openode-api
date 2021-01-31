require 'public_suffix'

class WebsiteLocation < ApplicationRecord
  serialize :obj, JSON

  MAIN_SERVICE_NAME = 'main-service'
  MAX_REPLICAS = 5
  LIMIT_RAM_WITH_REPLICAS = 1000

  belongs_to :website
  belongs_to :location
  belongs_to :location_server, optional: true
  has_many :deployments

  validates :location, presence: true
  validates :website, presence: true

  validate :validate_nb_cpus
  validate :unique_location_per_website
  validate :replicas_limitation_with_extra_storage
  validate :replicas_limitation_based_on_the_plan

  validates :extra_storage, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 10
  }

  validates :replicas, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 1,
    less_than_or_equal_to: MAX_REPLICAS
  }

  def main_service
    obj&.dig('services', 'items')&.find do |item|
      item&.dig('metadata', 'name') == MAIN_SERVICE_NAME
    end
  end

  def cluster_ip
    main_service&.dig('spec', 'clusterIP')
  end

  def validate_nb_cpus
    return unless location_server

    max_cpus = (location_server.cpus * 0.75).to_i
    max_cpus = 1 if max_cpus < 1

    if nb_cpus <= 0 || nb_cpus > max_cpus
      errors.add(:nb_cpus, "Invalid value, valid ones: [1..#{max_cpus}]")
    end
  end

  def replicas_limitation_with_extra_storage
    if replicas > 1 && extra_storage.positive?
      errors.add(:replicas, 'permanent storage cannot be used with replicas > 1')
    end
  end

  def replicas_limitation_based_on_the_plan
    if replicas > 1 && website.plan[:ram] > LIMIT_RAM_WITH_REPLICAS
      errors.add(:replicas, "maximum plan is #{LIMIT_RAM_WITH_REPLICAS} MB " \
                            "with replicas > 1")
    end
  end

  def unique_location_per_website
    if website.website_locations.any? { |wl| wl.id != id && wl.location_id == location_id }
      errors.add(:location, 'already exists for this site')
    end
  end

  def self.internal_domains
    CloudProvider::Manager.instance.internal_domains
  end

  def prepare_runner_configs_docker
    {
      website: website,
      website_location: self,
      host: location_server.ip,
      secret: location_server.secret
    }
  end

  def prepare_runner_configs_kubernetes
    cloud_provider_manager = CloudProvider::Manager.instance
    build_server = cloud_provider_manager.docker_build_server

    {
      website: website,
      website_location: self,
      host: build_server['ip'],
      secret: {
        user: build_server['user'],
        private_key: build_server['private_key']
      }
    }
  end

  def prepare_runner_configs
    send("prepare_runner_configs_#{website.type}")
  end

  def prepare_runner
    return if !location_server && website.type == Website::TYPE_DOCKER

    configs = send("prepare_runner_configs_#{website.type}")

    @runner =
      DeploymentMethod::Runner.new(website.type, website.cloud_type, configs)

    @runner
  end

  def available_plans
    manager = CloudProvider::Manager.instance

    manager.available_plans_of_type_at(website.cloud_type, location.str_id)
  end

  def notify_force_stop(reason)
    last_stop_event = website.stop_events.last

    unless last_stop_event
      StopWebsiteEvent.create(website: website, obj: { reason: reason })
      website.create_event(title: reason)

      WebsiteNotification.create(
        website: website,
        level: WebsiteNotification::LEVEL_CRITICAL,
        content: reason
      )

      UserMailer.with(
        user: website.user,
        website: website,
        reason: reason
      ).stopped_due_reason.deliver_now
    end
  end

  # main domain used internally
  def main_domain
    send "domain_#{website.domain_type}"
  end

  def domain_subdomain
    location_subdomain = Location::SUBDOMAIN[location.str_id.to_sym]

    first_part = if location_subdomain && location_subdomain != ''
                   "#{website.site_name}.#{location_subdomain}"
                 else
                   website.site_name.to_s
                 end

    "#{first_part}.#{CloudProvider::Manager.base_hostname}"
  end

  def domain_custom_domain
    website.site_name
  end

  def self.root_domain(domain_name)
    PublicSuffix.domain(domain_name)
  end

  def root_domain
    WebsiteLocation.root_domain(main_domain)
  end

  def compute_domains
    case website.domain_type
    when 'subdomain'
      [main_domain]
    when 'custom_domain'
      website.domains
    end
  end

  def gen_ssh_key!
    k = SSHKey.generate

    save_secret!(
      public_key: k.ssh_public_key,
      private_key: k.private_key
    )

    secret
  end

  ### storage
  def change_storage!(amount_gb)
    if amount_gb.positive? && !website&.user&.orders?
      msg_requires_paid_instance = "Persitence is only available for paid instances."
      raise ValidationError, msg_requires_paid_instance

    end

    self.extra_storage += amount_gb
    save!
  end

  # for example given www2.www.google.com,
  # root domain is google.com, so name = www2.www
  def self.name_of_domain(domain)
    root_domain_current = WebsiteLocation.root_domain(domain)

    parts = domain.split(root_domain_current)

    return '' if parts.empty?

    parts.first.delete_suffix('.')
  end

  def allocate_ports!
    return if (port && second_port) || !location_server_id

    ports_used =
      WebsiteLocation.where(location_server_id: location_server_id)
                     .pluck(:port, :running_port, :second_port)
                     .flatten

    self.port = generate_port(5000, 65_534, ports_used)
    self.second_port = generate_port(5000, 65_534, ports_used + [port])
    self.running_port = nil
    save!
  end

  def ports
    [port, second_port]
      .select(&:present?)
  end

  protected

  def generate_port(min, max, other_reserved = [])
    reserved_ports = [3306, 6379, 27_017, 27_018, 27_019] + other_reserved
    port = nil

    port = rand(min..max) while !port || reserved_ports.include?(port)

    port
  end
end
