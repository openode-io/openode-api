require 'vultr'

namespace :verify_dns do
  desc "This task does nothing"
  task :entries do
    internal_domains = ["openode.io", "openode.dev"]

    Vultr.api_key = ENV["VULTR_API_KEY"]
    dns_entries = Vultr::DNS.list


  end
end
