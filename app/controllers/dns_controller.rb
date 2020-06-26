class DnsController < InstancesController
  before_action :ensure_location

  before_action only: %i[add_alias del_alias settings] do
    requires_custom_domain
  end

  before_action only: %i[add_alias del_alias] do
    requires_access_to(Website::PERMISSION_ALIAS)
  end

  def add_alias
    domain = Website.clean_domain(params['hostname'])

    @website.domains ||= []
    @website.domains << domain
    @website.save!

    @website.create_event(title: 'Add domain alias', domain: domain)

    json(result: 'success')
  end

  def del_alias
    domain = Website.clean_domain(params['hostname'])

    @website.domains ||= []
    @website.domains.delete(domain)
    @website.save!

    @website.create_event(title: 'Delete domain alias', domain: domain)

    json(result: 'success')
  end

  api!
  def settings
    # returns the custom domain DNS settings
    location_str_id = @website_location.location.str_id

    configs_at = DeploymentMethod::Kubernetes.kube_configs_at_location(location_str_id)

    json(
      external_addr: configs_at['external_addr'],
      cname: configs_at['cname']
    )
  end
end
