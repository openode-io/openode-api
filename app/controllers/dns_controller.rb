class DnsController < InstancesController

  before_action :ensure_location

  before_action only: [:list_dns, :add_dns, :del_dns] do
    requires_custom_domain
  end

  before_action only: [:add_dns, :del_dns] do
    requires_location_server
  end

  def list_dns
    json(@website_location.compute_dns({ with_auto_a: true }))
  end

  def add_dns
  	domain = params["domainName"]
  	type = params["type"]
  	value = params["value"]
  	priority = params["priority"]

  	manager = Remote::Dns::Base.instance

  	# make sure the root domain is created
  	server = @website_location.location_server
  	manager.add_root_domain_if_not_exists(@website_location.root_domain, server.ip)

  	# add the DNS entry
  	manager.add_domain_name_record(
  		@website_location.root_domain, 
  		domain, 
  		type, 
  		value, 
  		priority
  	)

  	new_entry = { "domainName" => domain, "type" => type, "value" => value, "priority" => priority }

  	@website.dns ||= []
  	@website.dns << new_entry
  	@website.save!

  	@website.create_event({ title: "Add DNS entry", entry: new_entry })

  	list_dns
  end

  def del_dns
  	dns_id = params["id"]

  	manager = Remote::Dns::Base.instance

  	entry = @website_location.find_dns_entry_by_id(dns_id)

  	unless entry
  		validation_error!("This entry does not exist.")
  	end

  	@website.remove_dns_entry(entry)
  	@website.save!

  	# update the remove DNS
  	@website.reload
  	@website_location.update_remote_dns({ with_auto_a: true })

  	@website.create_event({ title: "Remove DNS entry", entry: entry })

  	list_dns
  end

  private



end
