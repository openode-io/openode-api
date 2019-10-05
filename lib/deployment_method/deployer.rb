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
			    cmd_name: "launch", options: { is_complex: true }
			  },
			  {
			    cmd_name: "verify_instance_up", options: { is_complex: true }
			  }
			])
		rescue => ex
			Rails.logger.info("Issue deploying #{website.site_name}, #{ex.backtrace}")
		end

		begin
			runner.execute([
			  {
			    cmd_name: "finalize", options: { is_complex: true }
			  }
			])
		rescue => ex
			Rails.logger.info("Issue finalizing deployment #{website.site_name}, #{ex.backtrace}")
		end

  		Rails.logger.info("Finished deployment for #{website.site_name}...")
  	end

  end
end