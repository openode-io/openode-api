module DeploymentMethod

  class Base

  	attr_accessor :runner

  	REMOTE_PATH_API_LIB = "/root/openode-www/api/lib"

    def verify_can_deploy(options = {})
      assert options[:website]
      assert options[:website_location]
      website, website_location = options.values_at(:website, :website_location)

      can_deploy, msg = website.can_deploy_to?(website_location)

      unless can_deploy
        raise ApplicationRecord::ValidationError.new(msg)
      end
    end

  	protected
  	def ex(cmd, options = {})
  		self.runner.execute([{ cmd_name: cmd, options: options }]).first
  	end

  	def ex_stdout(cmd, options = {})
  		self.runner.execute([{ cmd_name: cmd, options: options }]).first[:stdout]
  	end

    private
    def require_fields(fields, options)
      fields.each do |field|
        assert options[field]
      end
    end

  end

end