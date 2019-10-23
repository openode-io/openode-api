# frozen_string_literal: true

module DeploymentMethod
  class Deployer
    def self.run(website_location, runner, options = {})
      assert runner

      runner.init_execution!(options[:execution_type]) if options[:execution_type]

      assert runner.execution
      website = website_location.website

      Rails.logger.info("Starting execution for #{website.site_name}, " \
        "execution-id = #{runner.execution.id}...")

      begin
      runner.multi_steps.execute([
                                   {
                                     cmd_name: 'verify_can_deploy', options: { is_complex: true }
                                   },
                                   {
                                     cmd_name: 'initialization', options: { is_complex: true }
                                   },
                                   {
                                     cmd_name: 'launch', options: {
                                       is_complex: true,
                                       limit_resources: runner.cloud_provider.limit_resources?
                                     }
                                   },
                                   {
                                     cmd_name: 'verify_instance_up', options: { is_complex: true }
                                   }
                                 ])
      rescue StandardError => e
        Ex::Logger.info(e, "Issue deploying #{website.site_name}")
        runner.execution.add_error!(e)
        runner.execution.failed!
        website.change_status!(Website::STATUS_OFFLINE)
    end

      begin
        runner.execute([
                         {
                           cmd_name: 'finalize', options: { is_complex: true }
                         }
                       ])
      rescue StandardError => e
        Ex::Logger.info(e, "Issue finalizing execution #{website.site_name}")
        runner.execution.add_error!(e)
        runner.execution.failed!
      end

      Rails.logger.info("Finished execution for #{website.site_name}, status=#{runner.execution.status}...")
    end
  end
end
