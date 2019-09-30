module DeploymentMethod

  class Base
    RuntimeError = Class.new(StandardError)

  	attr_accessor :runner

  	REMOTE_PATH_API_LIB = "/root/openode-www/api/lib"
    DEFAULT_CRONTAB_FILENAME = ".openode.cron"

    def error!(msg)
      raise RuntimeError.new(msg)
    end

    def verify_can_deploy(options = {})
      assert options[:website]
      assert options[:website_location]
      website, website_location = options.values_at(:website, :website_location)

      can_deploy, msg = website.can_deploy_to?(website_location)

      unless can_deploy
        raise ApplicationRecord::ValidationError.new(msg)
      end
    end

    def mark_accessed(options = {})
      assert options[:website]
      website = options[:website]
      website.last_access_at = Time.now
      website.save
    end

    def initialization(options = {})
      assert options[:website]
      assert options[:website_location]
      website = options[:website]
      website_location = options[:website_location]

      self.mark_accessed(options)
      website.change_status!(Website::STATUS_STARTING)
      website_location.allocate_ports!
    end

  	protected
  	def ex(cmd, options = {})
  		result = self.runner.execute([{ cmd_name: cmd, options: options }]).first

      if options[:ensure_exit_code].present?
        if result && result[:exit_code] != options[:ensure_exit_code]
          self.error!("Failed to run #{cmd}, result=#{result.inspect}")
        end
      end

      result
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