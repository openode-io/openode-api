class SuperAdmin::WebsitesController < SuperAdmin::SuperAdminController
  before_action do
    if params['id']
      @website = Website.find_by! id: params['id']
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
    json(
      WebsiteLocation.where(load_balancer_synced: false)
      .map do |wl|
        {
          website_id: wl.id
        }
      end
    )
  end

  protected

  def open_source_request_params
    params.require(:open_source_request).permit(:status, :reason)
  end
end
