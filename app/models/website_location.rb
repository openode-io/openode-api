class WebsiteLocation < ApplicationRecord
  belongs_to :website
  belongs_to :location
  belongs_to :location_server

  def domain
    if self.website.domain_type == "subdomain"
      location_subdomain = Location::SUBDOMAIN[self.location.str_id.to_sym]

      first_part = ""

      if location_subdomain && location_subdomain != ""
        first_part = "#{self.website.site_name}.#{location_subdomain}"
      else
        first_part = "#{self.website.site_name}"
      end

      "#{first_part}.openode.io"
    elsif self.website.domain_type == "custom_domain"
      self.website.site_name
    end
  end

end
