
require "vultr"

module Remote
	module Dns
		class Vultr < Base

			def initialize
		      # ::Vultr.api_key = configs["api_key"]
			end

			def wait_api
				sleep 0.5
			end

			def all_root_domains
				wait_api
				list = ::Vultr::DNS.list[:result]
				list.map { |entry| entry["domain"] }
			end

			def add_root_domain(domain, default_server_ip)
				wait_api
				::Vultr::DNS.create_domain({domain: domain, serverip: default_server_ip})[:result]
			end

			def domain_records(domain)
				wait_api
				::Vultr::DNS.records(domain: domain)[:result]
					.map do |record|
						record["value"] = record["data"]

						record
					end
			end

			def add_record(root_domain, name, type, value, priority)
				wait_api
				::Vultr::DNS.create_record({
					domain: root_domain,
					name: name,
					type: type,
					data: value,
					priority: priority
				})[:result]
			end

			def delete_record(root_domain, record)
				wait_api
				::Vultr::DNS.delete_record({
					domain: root_domain,
					RECORDID: record["RECORDID"]
				})[:result]
			end
		end
	end
end