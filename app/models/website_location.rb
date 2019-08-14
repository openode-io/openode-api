class WebsiteLocation < ApplicationRecord
  belongs_to :website
  belongs_to :location
  belongs_to :location_server

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

end
