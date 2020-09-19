class SnapshotWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'default', retry: false

  def perform(website_location_id, snapshot_id)
    website_location = WebsiteLocation.find(website_location_id)
    snapshot = Snapshot.find(snapshot_id)

    runner = website_location.prepare_runner
    runner.execute([{
                     cmd_name: 'make_snapshot',
                     options: { is_complex: true, snapshot: snapshot }
                   }])

    runner.execute([{ cmd_name: 'reload', options: { is_complex: true } }])
  end
end
