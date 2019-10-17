module Remote
	module Dns
		class Base
			def self.instance(type = "vultr")
				"Remote::Dns::#{type.capitalize}".constantize.new
			end

			def all_root_domains
				raise "missing implementation"
			end

			def add_root_domain(domain, ip)
				raise "missing implementation"
			end

			# return [ { name, type, value } ]
			def domain_records(domain)
				raise "missing implementation"
			end

			def add_record(root_domain, name, type, value, priority)
				raise "missing implementation"
			end

			def dns_entry_exists?(root_domain, existing_records, dns_entry)
				existing_records.any? do |record|
					first_part_domain = record["name"] ? "#{record["name"]}." : ""

					"#{first_part_domain}#{root_domain}" == dns_entry["domainName"] &&
						"#{record["type"]}" == dns_entry["type"] &&
						"#{record["value"]}" == dns_entry["value"]
				end
			end

			# returns the ones created, the ones deleted
			def update(root_domain, main_domain, domains, dns_entries, main_ip)
				result = {
					created: [],
					deleted: []
				}

				unless self.all_root_domains.include?(root_domain)
					self.add_root_domain(root_domain, main_ip)
				end

				records = self.domain_records(root_domain)

				# which records should we CREATE ?
				dns_entries.each do |dns_entry|
					unless dns_entry_exists?(root_domain, records, dns_entry)
						self.add_record(root_domain, dns_entry["name"],
							dns_entry["type"], dns_entry["value"], dns_entry["priority"])
						result[:created] << dns_entry
					end
				end

				result
			end
		end
	end
end