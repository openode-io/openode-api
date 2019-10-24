# frozen_string_literal: true

class SnapshotsController < InstancesController
  before_action :requires_cloud_plan, only: [:create]

  def index
    json(@website.snapshots.order(created_at: :desc).limit(100))
  end

  def show
    json(@website.snapshots.find_by!(id: params['id']))
  end

  def create
    name = params['name']

    Snapshot.create!(
      name: name,
      website_id: @website.id,
      user_id: @website.user_id
    )

    @website_event_obj = { title: 'snapshot-initiated', name: name }

    json(
      result: 'success',
      description: 'The snapshot will start transferring'
    )
  end

  def destroy
    snapshot = @website.snapshots.find_by! id: params['id']

    if %w[to_delete deleted].include?(snapshot.status)
      raise ApplicationRecord::ValidationError, 'Snapshot already deleted'
    end

    @website_event_obj = { title: 'snapshot-deleted', id: snapshot.id }

    snapshot.change_status!('to_delete')

    json(result: 'success', description: 'The snapshot will be removed shortly')
  end
end
