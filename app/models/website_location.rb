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
    return unless self.location_server

    max_cpus = (self.location_server.cpus * 0.75).to_i
    max_cpus = 1 if max_cpus < 1

    if self.nb_cpus <= 0 || self.nb_cpus > max_cpus
      errors.add(:nb_cpus, "Invalid value, valid ones: [1..#{max_cpus}]")
    end
  end

  def unique_location_per_website
    if website.website_locations.any? { |wl| wl.id != self.id && wl.location_id == self.location_id }
      errors.add(:location, "already exists for this site")
    end
  end

  def self.internal_domains
    CloudProvider::Manager.instance.internal_domains
  end

  def prepare_runner
    configs = {
      website: website,
      website_location: self,
      host: location_server.ip,
      secret: location_server.secret
    }

    @runner =
      DeploymentMethod::Runner.new(website.type, website.cloud_type, configs)

    @runner
  end

  def has_location_server?
    location_server.present?
  end

  def available_plans
    manager = CloudProvider::Manager.instance

    manager.available_plans_of_type_at(website.cloud_type, location.str_id)
  end

  # main domain used internally
  def main_domain
    send "domain_#{self.website.domain_type}"
  end

  def domain_subdomain
    location_subdomain = Location::SUBDOMAIN[self.location.str_id.to_sym]

    first_part = ""

    if location_subdomain && location_subdomain != ""
      first_part = "#{self.website.site_name}.#{location_subdomain}"
    else
      first_part = "#{self.website.site_name}"
    end

    "#{first_part}.openode.io"
  end

  def domain_custom_domain
    self.website.site_name
  end

  def self.root_domain(domain_name)
    PublicSuffix.domain(domain_name)
  end

  def root_domain
    WebsiteLocation.root_domain(self.main_domain)
  end

  def compute_domains
    if website.domain_type == "subdomain"
      [self.main_domain]
    elsif website.domain_type == "custom_domain"
      website.domains
    end
  end

  def self.dns_entry_to_id(entry)
    Digest::MD5.hexdigest(entry.to_json)
  end

  def compute_dns(opts = {})
    result = (website.dns || []).clone

    if opts[:with_auto_a] && (opts[:location_server] || self.location_server)
      server = opts[:location_server] || self.location_server
      computed_domains = self.compute_domains

      result += WebsiteLocation.compute_a_record_dns(server, computed_domains)
    end

    result
      .map { |r| r["id"] = WebsiteLocation.dns_entry_to_id(r) ; r }
      .uniq { |r| r["id"] }
  end

  def gen_ssh_key!
    k = SSHKey.generate

    self.save_secret!({
      public_key: k.ssh_public_key,
      private_key: k.private_key
    })

    self.secret
  end

  ### storage
  def change_storage!(amount_gb)
    self.extra_storage += amount_gb
    self.save!
  end

  def self.compute_a_record_dns(location_server, computed_domains)
    result = []

    computed_domains.each do |domain|
      result << {
        "domainName" => domain,
        "type" => "A",
        "value" => location_server.ip
      }
    end

    result
  end

  def allocate_ports!
    return if self.port && self.second_port

    ports_used =
      WebsiteLocation.where(location_server_id: self.location_server_id).pluck(:port, :running_port, :second_port)
      .flatten

    self.port = self.generate_port(5000, 65534, ports_used)
    self.second_port = self.generate_port(5000, 65534, ports_used + [self.port])
    self.running_port = nil
    self.save!
  end

  def ports
    [self.port, self.second_port]
      .select { |p| p.present? }
  end

  def update_remote_dns(opts = {})
    actions_done = Remote::Dns::Base.instance.update(
      self.root_domain,
      self.main_domain,
      opts[:dns_entries] || self.compute_dns({ with_auto_a: opts[:with_auto_a] }),
      self.location_server.ip
    )

    self.website.create_event({ title: 'DNS update', updates: actions_done })

    actions_done
  end

  protected

  def generate_port(min, max, other_reserved = [])
    reserved_ports = [3306, 6379, 27017, 27018, 27019] + other_reserved
    port = nil

    while ! port || reserved_ports.include?(port) do
      port = rand(min..max)
    end

    return port
  end

  private
  

end
