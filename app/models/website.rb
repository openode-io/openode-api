class Website < ApplicationRecord

  serialize :domains, JSON
  serialize :configs, JSON

  self.inheritance_column = :_type

  belongs_to :user
  has_many :website_locations
  has_many :events, foreign_key: :ref_id, class_name: :WebsiteEvent

  scope :custom_domain, -> { where(domain_type: "custom_domain") }

  validates :site_name, presence: true
  validates :site_name, uniqueness: true
  validates :type, presence: true
  validates :domain_type, presence: true
  validates :cloud_type, presence: true

  validate :configs_must_comply

  validates_inclusion_of :type, :in => %w( nodejs docker )
  validates_inclusion_of :domain_type, :in => %w( subdomain custom_domain )
  validates_inclusion_of :cloud_type, :in => %w( cloud "private-cloud" )

  def configs_must_comply
    self.configs ||= {}

    self.configs.each do |var_name, value|
      config = Website.config_def(var_name)

      next if ! config

      if config[:enum] && ! config[:enum].include?(value)
        errors.add(:configs, "Invalid value, valid ones: #{config[:enum]}")
      end

      if config[:min] && config[:max]
        parsed_val = value.to_f

        if ! (parsed_val.present? && parsed_val >= config[:min] && parsed_val <= config[:max])
          errors.add(:configs, "Invalid value, , min = #{config[:min]}, max = #{config[:max]}")
        end
      end
    end
  end

  CONFIG_VARIABLES = [
    {
      variable: "SSL_CERTIFICATE_PATH",
      description: "Certificate file. Example: certs/mysite.crt"
    },
    {
      variable: "SSL_CERTIFICATE_KEY_PATH",
      description: "Private key generated. Example: certs/privatekey.key"
    },
    {
      variable: "REDIR_HTTP_TO_HTTPS",
      description: "Will redirect HTTP traffic to HTTPS. An HTTPS server is required.",
      type: "website",
      enum: ["true", "false", ""]
    },
    {
      variable: "MAX_BUILD_DURATION",
      description: "The build duration limit in seconds.",
      min: 50,
      default: 100,
      max: 600
    },
    {
      variable: "SKIP_PORT_CHECK",
      description: "Skip the port verification while deploying.",
      enum: ["true", "false", ""]
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
end
