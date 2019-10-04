module DeploymentMethod
  class Deployer

  	def self.run(website_location, runner)
  		website = website_location.website
  		puts "RUNNING"

  		sleep 1

  		Rails.logger.info("Starting deployment for #{website.site_name}...")

		#runner.execute([
		#  {
		#    cmd_name: "verify_can_deploy", options: { is_complex: true }
		#  },
		#  { 
		#    cmd_name: "initialization", options: { is_complex: true }
		#  },
		#  {
		#    cmd_name: "launch", options: { is_complex: true }
		#  },
		#  {
		#    cmd_name: "verify_instance_up", options: { is_complex: true }
		#  }
		#])

		#runner.execute([
		#  {
		#    cmd_name: "finalize", options: { is_complex: true }
		#  }
		#])
  	end

  end
end