class SnapshotsController < InstancesController

  def show
    snapshot = @website.snapshots.find_by! id: params["id"]

    json_res(snapshot)
  end

  protected

end
