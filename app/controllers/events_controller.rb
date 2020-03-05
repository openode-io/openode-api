class EventsController < InstancesController
  before_action do
    if params['id']
      @event = @website.events.find_by! id: params['id']
    end
  end

  api!
  def index
    attributes_to_search = %w[ref_id obj]

    json(default_listing(WebsiteEvent, attributes_to_search)
        .where(ref_id: @website.id))
  end

  api!
  def retrieve
    json(@event)
  end
end
