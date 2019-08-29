require 'public_suffix'

class WebsiteLocation < ApplicationRecord
  belongs_to :website
  belongs_to :location
  belongs_to :location_server

  validates :extra_storage, numericality: { only_integer: true, less_than_or_equal_to: 10 }

  INTERNAL_DOMAINS = ["openode.io", "openode.dev"]

  def domain
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
    WebsiteLocation.root_domain(self.domain)
  end

  ### storage
  def increase_storage!(amount_gb)
    self.extra_storage += amount_gb
    self.save!
  end
end
