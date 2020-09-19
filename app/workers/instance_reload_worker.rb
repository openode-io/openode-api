class InstanceReloadWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'critical', retry: false

  def perform(website_location_id, execution_id)
    website_location = WebsiteLocation.find(website_location_id)
    execution = Execution.find(execution_id)

    runner = website_location.prepare_runner
    runner.execution = execution

    runner.execute([{ cmd_name: 'reload', options: { is_complex: true } }])
  end
end
