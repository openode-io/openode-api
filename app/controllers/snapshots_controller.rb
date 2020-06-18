# snapshot_controller.rb

class SnapshotsController < InstancesController
  before_action only: %i[create_snapshot] do
    requires_status_in [Website::STATUS_ONLINE]
  end

  api :POST, 'instances/:id/snapshots'
  description 'Make a snapshot of the files at a given path.'
  param :path, String, desc: "", required: true
  def create_snapshot
    path = params[:path]
    snapshot = Snapshot.create!(website: @website, path: path)

    @runner&.delay&.execute([{
                              cmd_name: 'make_snapshot',
                              options: { is_complex: true, snapshot: snapshot }
                            }])

    result = {
      url: snapshot.url,
      expires_in: "#{(snapshot.expire_at - Time.zone.now) / 60} minutes",
      details: snapshot
    }

    @website_event_obj = { title: 'create-snapshot', result: result }

    json(result)
  end
end
