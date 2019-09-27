class SnapshotsController < InstancesController

  before_action :requires_cloud_plan, only: [:create]

  def show
    snapshot = @website.snapshots.find_by! id: params["id"]

    json(snapshot)
  end

  def create
    name = params["name"]

    Snapshot.create!({
      name: name,
      website_id: @website.id,
      user_id: @website.user_id
    })

    @website_event_obj = { title: "snapshot-initiated", name: name }

    json({
      result: "success",
      description: "The snapshot will start transferring"
    })
  end

  protected

end
