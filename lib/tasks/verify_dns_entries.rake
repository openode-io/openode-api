require 'vultr'

namespace :verify_dns do
  desc "This task does nothing"
  task :entries do

    # get all custom domain site names
    site_names = Website.custom_domain.pluck(:site_name)

    # get DNS entries
    Vultr.api_key = ENV["VULTR_API_KEY"]
    dns_entries = Vultr::DNS.list[:result]

    dns_entries.each do |dns_entry|
      next if WebsiteLocation::INTERNAL_DOMAINS.include? dns_entry["domain"]

      puts "current .. #{dns_entry.inspect}"

      site_names_found = site_names.select do |name|
        WebsiteLocation.root_domain(name) == dns_entry["domain"]
      end

      puts "site found ? #{site_names_found}"

      if site_names_found.length == 0
        puts "warning !"
      end
    end

  end
end
