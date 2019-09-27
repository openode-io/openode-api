class DnsController < InstancesController

  before_action :ensure_location

  def list_dns
    if @website.domain_type != "custom_domain"
      raise ApplicationRecord::ValidationError.new("DNS is for custom domains only.")
    end

    dns = @website_location.compute_dns({ with_auto_a: true })

    json(dns)
  end

  protected

end
