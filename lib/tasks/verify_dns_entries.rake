require 'vultr'

namespace :verify_dns do
  desc "This task does nothing"
  task :entries do

    # get all custom domain site names
    site_names = Website.custom_domain.pluck(:site_name)
    Rails.logger.info "#{site_names.length} sites to check"

    # get DNS entries
    Vultr.api_key = ENV["VULTR_API_KEY"]
    dns_entries = Vultr::DNS.list[:result]

    dns_entries.each do |dns_entry|
      next if WebsiteLocation::INTERNAL_DOMAINS.include? dns_entry["domain"]

      site_names_found = site_names.select do |name|
        WebsiteLocation.root_domain(name) == dns_entry["domain"]
      end

      if site_names_found.length == 0
        Rails.logger.info "Removing DNS domain #{dns_entry}"
        Vultr::DNS.delete_domain(domain: dns_entry["domain"])
      end
    end

  end
end
