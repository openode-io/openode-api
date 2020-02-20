class ExecutionsController < InstancesController
  before_action do
    if params['id']
      @execution = @website.executions.find_by! id: params['id']
    end
  end

  api!
  def index
    attributes_to_search = %w[website_id status result type events]

    json(default_listing(Execution, attributes_to_search, order: "id DESC")
        .where(type: params['type'])
        .where(website_id: @website.id)
        .select(:id, :website_id, :type, :status, :created_at))
  end

  def retrieve
    json(@execution)
  end
end
