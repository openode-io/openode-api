require 'public_suffix'

class WebsiteLocation < ApplicationRecord
  belongs_to :website
  belongs_to :location
  belongs_to :location_server, optional: true
  has_many :deployments

  validates :location, presence: true
  validates :website, presence: true

  validate :validate_nb_cpus
  validate :unique_location_per_website

  validates :extra_storage, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 10
  }

  def validate_nb_cpus
    return unless location_server

    max_cpus = (location_server.cpus * 0.75).to_i
    max_cpus = 1 if max_cpus < 1

    if nb_cpus <= 0 || nb_cpus > max_cpus
      errors.add(:nb_cpus, "Invalid value, valid ones: [1..#{max_cpus}]")
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

  # main domain used internally
  def main_domain
    send "domain_#{website.domain_type}"
  end

  def domain_subdomain
    if website.type == Website::TYPE_KUBERNETES
      # temporarily, remove when beta finished
      return "#{website.site_name}.dev.#{CloudProvider::Manager.base_hostname}"
    end

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
    if website.domain_type == 'subdomain'
      [main_domain]
    elsif website.domain_type == 'custom_domain'
      website.domains
    end
  end

  def self.dns_entry_to_id(entry)
    Digest::MD5.hexdigest(entry.to_json)
  end

  def compute_dns(opts = {})
    result = (website.dns || []).clone

    if opts[:with_auto_a] && (opts[:location_server] || location_server)
      server = opts[:location_server] || location_server
      computed_domains = compute_domains

      result += WebsiteLocation.compute_a_record_dns(server, computed_domains)
    end

    result
      .map do |r|
        r['id'] = WebsiteLocation.dns_entry_to_id(r)
        r
      end
      .uniq { |r| r['id'] }
  end

  def find_dns_entry_by_id(id)
    compute_dns
      .find { |entry| entry['id'] == id }
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

  def self.compute_a_record_dns(location_server, computed_domains)
    result = []

    computed_domains.each do |domain|
      result << {
        'name' => WebsiteLocation.name_of_domain(domain),
        'domainName' => domain,
        'type' => 'A',
        'value' => location_server.ip
      }
    end

    result
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

  def add_server!(attribs = {})
    server = LocationServer.find_by ip: attribs[:ip]
    return server if server

    attribs[:location_id] = location_id
    server = LocationServer.create!(attribs)

    self.location_server_id = server.id
    save!

    reload
    update_remote_dns(with_auto_a: true)

    server
  end

  def ports
    [port, second_port]
      .select(&:present?)
  end

  def update_remote_dns(opts = {})
    actions_done = Remote::Dns::Base.instance.update(
      root_domain,
      main_domain,
      opts[:dns_entries] || compute_dns(with_auto_a: opts[:with_auto_a]),
      location_server.andand.ip
    )

    website.create_event(title: 'DNS update', updates: actions_done)

    actions_done
  end

  protected

  def generate_port(min, max, other_reserved = [])
    reserved_ports = [3306, 6379, 27_017, 27_018, 27_019] + other_reserved
    port = nil

    port = rand(min..max) while !port || reserved_ports.include?(port)

    port
  end
end
