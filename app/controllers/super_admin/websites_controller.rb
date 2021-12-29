class SuperAdmin::WebsitesController < SuperAdmin::SuperAdminController
  before_action do
    if params['id']
      @website = Website.find_by! id: params['id']
    end

    if params['website_location_id']
      @website_location = WebsiteLocation.find_by! id: params['website_location_id']
    end
  end

  def index
    attributes_to_search = [
      "websites.id", "users.id", "users.email", "websites.site_name",
      "websites.account_type", "websites.status"
    ]

    json(default_listing(Website, attributes_to_search, order: "websites.id DESC")
        .includes(website_locations: :location)
        .preload(:user)
        .joins(:user)
        .map do |w|
          w.attributes.merge(locations: w.website_locations.map(&:location))
        end)
  end

  def retrieve
    result = @website.attributes

    json(result)
  end

  def update_open_source_request
    req_open_source = open_source_request_params

    @website.open_source ||= {}
    @website.open_source['status'] = req_open_source['status']
    @website.open_source['reason'] = req_open_source['reason']

    @website.open_source_activated =
      @website.open_source['status'] == Website::OPEN_SOURCE_STATUS_APPROVED
    @website.save!

    UserMailer.with(website: @website, user: @website.user)
              .response_open_source_request.deliver_now

    json({})
  end

  def load_balancer_requiring_sync
    website_locations = filter_location(
      WebsiteLocation.includes(:website).where(load_balancer_synced: false)
    )

    json(
      website_locations
      .map do |wl|
        prepare_website_location_listing(wl)
      end
    )
  end

  def online_of_type
    website_locations = WebsiteLocation.includes(:website).where(
      "websites.status = ? AND websites.type = ?",
      Website::STATUS_ONLINE,
      params["type"]
    ).references(:websites)

    json(
      filter_location(website_locations)
      .map do |wl|
        prepare_website_location_listing(wl)
      end
    )
  end

  def update
    @website_location.attributes = website_location_params
    @website_location.save!

    json({})
  end

  protected

  def filter_location(website_locations)
    if params["location"]
      location = Location.find_by! str_id: params["location"]
      website_locations = website_locations.where("location_id = ?", location.id)
    end

    website_locations
  end

  def prepare_website_location_listing(website_location)
    wl = website_location

    {
      id: wl.id,
      website_id: wl.website.id,
      hosts: wl.compute_domains,
      backend_url: wl.obj&.dig("gcloud_url"),
      execution_layer: wl.website.get_config("EXECUTION_LAYER"),
      domain_type: wl.website.domain_type,
      cname: wl.deployment_method_configs&.dig("cname"),
      has_certificate: wl.website.certs.present? || wl.website.subdomain?,
      gcloud_ssl_cert_url: wl.obj&.dig("gcloud_ssl_cert_url"),
      gcloud_ssl_key_url: wl.obj&.dig("gcloud_ssl_key_url"),
      redir_http_to_https: wl.website.get_config("REDIR_HTTP_TO_HTTPS")
    }
  end

  def open_source_request_params
    params.require(:open_source_request).permit(:status, :reason)
  end

  def website_location_params
    params.require(:website_location).permit(:load_balancer_synced)
  end
end
