class Website < ApplicationRecord

  self.inheritance_column = :_type

  belongs_to :user
  has_many :website_locations

  scope :custom_domain, -> { where(domain_type: "custom_domain") }

  validates :site_name, presence: true
  validates :site_name, uniqueness: true
  validates :type, presence: true
  validates :domain_type, presence: true
  validates :cloud_type, presence: true

  validates_inclusion_of :type, :in => %w( nodejs docker )
  validates_inclusion_of :domain_type, :in => %w( subdomain custom_domain )
  validates_inclusion_of :cloud_type, :in => %w( cloud "private-cloud" )

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
      enum: [true, false]
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
end
