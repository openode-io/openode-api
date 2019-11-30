require 'vultr'

namespace :verify_dns do
  desc 'Verify and clean DNS entries'
  task entries: :environment do
    task_name = "Task verify_dns:entries"
    Rails.logger.info "[#{task_name}] begin"

    # get all custom domain site names
    site_names = Website.custom_domain.pluck(:site_name)
    Rails.logger.info "[#{task_name}] #{site_names.length} sites to check"

    # get DNS entries
    Vultr.api_key = ENV['VULTR_API_KEY']
    dns_entries = Vultr::DNS.list[:result]

    dns_entries.each do |dns_entry|
      next if WebsiteLocation.internal_domains.include? dns_entry['domain']

      site_names_found = site_names.select do |name|
        WebsiteLocation.root_domain(name) == dns_entry['domain']
      end

      if site_names_found.empty?
        Rails.logger.info "[#{task_name}] Removing DNS domain #{dns_entry}"
        Vultr::DNS.delete_domain(domain: dns_entry['domain'])
      end
    end
  end
end
