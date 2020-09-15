# snapshot_controller.rb

class SnapshotsController < InstancesController
  before_action do
    if params['id']
      @snapshot = @website.snapshots.find_by! id: params['id']
    end
  end

  before_action only: %i[create_snapshot] do
    requires_status_in [Website::STATUS_ONLINE]
  end

  api :GET, 'instances/:site_name/snapshots'
  description 'Retrieve the recent snapshots.'
  def index
    attributes_to_search = %w[website_id status uid path steps]

    result = default_listing(Snapshot, attributes_to_search, order: "id DESC")
             .where(website_id: @website.id)

    json(result)
  end

  api :GET, 'instances/:site_name/snapshots/:id'
  def retrieve
    json(@snapshot)
  end

  api :POST, 'instances/:id/snapshots'
  description 'Make a snapshot of the files at a given path.'
  param :path, String, desc: "", required: true
  def create_snapshot
    path = params[:path]
    snapshot = Snapshot.create!(website: @website, path: path)

    SnapshotWorker.perform_async(@website_location.id, snapshot.id)

    result = {
      url: snapshot.url,
      expires_in: "#{(snapshot.expire_at - Time.zone.now) / 60} minutes",
      details: snapshot
    }

    @website_event_obj = { title: 'create-snapshot', result: result }

    json(result)
  end
end
