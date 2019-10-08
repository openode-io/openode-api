module DeploymentMethod
  class Deployer

  	def self.run(website_location, runner)
  		assert runner
  		assert runner.deployment
  		website = website_location.website

  		Rails.logger.info("Starting deployment for #{website.site_name}, " +
  			"deployment-id = #{runner.deployment.id}...")

  		begin
			runner.execute([
			  {
			    cmd_name: "verify_can_deploy", options: { is_complex: true }
			  },
			  { 
			    cmd_name: "initialization", options: { is_complex: true }
			  },
			  {
			    cmd_name: "launch", options: {
			    	is_complex: true,
			    	limit_resources: runner.cloud_provider.limit_resources?
			    }
			  },
			  {
			    cmd_name: "verify_instance_up", options: { is_complex: true }
			  }
			])
		rescue => ex
			Ex::Logger.info(ex, "Issue deploying #{website.site_name}")
			runner.deployment.add_error!(ex)
			runner.deployment.failed!
			website.change_status!(Website::STATUS_OFFLINE)
		end

		begin
			runner.execute([
			  {
			    cmd_name: "finalize", options: { is_complex: true }
			  }
			])
		rescue => ex
			Ex::Logger.info(ex, "Issue finalizing deployment #{website.site_name}")
			runner.deployment.add_error!(ex)
			runner.deployment.failed!
		end

  		Rails.logger.info("Finished deployment for #{website.site_name}, status=#{runner.deployment.status}...")
  	end

  end
end