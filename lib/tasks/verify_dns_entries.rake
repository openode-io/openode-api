require 'vultr'

namespace :verify_dns do
  desc "This task does nothing"
  task :entries do

    Vultr.api_key = ENV["VULTR_API_KEY"]
    dns_entries = Vultr::DNS.list[:result]

    dns_entries.each do |dns_entry|
      next if WebsiteLocation::INTERNAL_DOMAINS.include? dns_entry["domain"]

      w = Website.find_by site_name: dns_entry["domain"]
      puts "cur entry.. #{dns_entry.inspect}"
      puts "w -> #{w ? w.site_name : "N/A"}"
    end

  end
end
