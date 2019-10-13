class PrivateCloudController < InstancesController

	before_action only: [:allocate] do
		requires_private_cloud_plan
	end

	def allocate
		if @website.data && @website.data["privateCloudInfo"]
			return json({ success: "Instance already allocated" })
		end

		unless @website.user.has_credits?
			raise ApplicationRecord::ValidationError.new("No credit available")
		end

		cloud_provider = CloudProvider::Manager.instance.first_of_type(CloudProvider::Vultr::TYPE)

		json({})
	end
end