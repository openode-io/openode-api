class InstanceStopWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'default', retry: false

  def perform(website_location_id)
    website_location = WebsiteLocation.find(website_location_id)

    runner = website_location.prepare_runner

    runner.execute([{ cmd_name: 'stop', options: { is_complex: true } }])
  end
end
