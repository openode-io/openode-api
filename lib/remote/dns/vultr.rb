
require "vultr"

module Remote
	module Dns
		class Vultr < Base

			def initialize
			end

			def all_root_domains
				list = ::Vultr::DNS.list[:result]
				list.map { |entry| entry["domain"] }
			end

			def add_root_domain(domain, default_server_ip)
				::Vultr::DNS.create_domain({domain: domain, serverip: default_server_ip})[:result]
			end

			def domain_records(domain)
				::Vultr::DNS.records(domain: domain)[:result]
					.map do |record|
						record["value"] = record["data"]

						record
					end
			end

			def add_record(root_domain, name, type, value, priority)
				::Vultr::DNS.create_record({
					domain: root_domain,
					name: name,
					type: type,
					data: value,
					priority: priority
				})[:result]
			end

			#def update(root_domain, main_domain, domains, dns)
			#	raise "missing implementation"
			#end
		end
	end
end