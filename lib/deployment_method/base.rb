module DeploymentMethod

  class Base
    RuntimeError = Class.new(StandardError)

  	attr_accessor :runner

  	REMOTE_PATH_API_LIB = "/root/openode-www/api/lib"
    DEFAULT_CRONTAB_FILENAME = ".openode.cron"

    def error!(msg)
      Rails.logger.error(msg)
      raise RuntimeError.new(msg)
    end

    def verify_can_deploy(options = {})
      website, website_location = get_website_fields(options)

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
      website, website_location = get_website_fields(options)

      self.mark_accessed(options)
      website.change_status!(Website::STATUS_STARTING)
      website_location.allocate_ports!
    end

    def instance_up_cmd(options = {})
      require_fields([:website_location], options)
      website_location = options[:website_location]

      port_info = port_info_for_new_deployment(website_location)
      url = "http://localhost:#{port_info[:port]}/"
      "curl --insecure --max-time 15 --connect-timeout 5 #{url} "
    end

    def node_available?(options = {})
      raise "node_available? must be defined in the child class"
    end

    def instance_up?(options = {})
      website = options[:website]

      if website.has_skip_port_check?
        node_available?(options)
      else
        return false unless node_available?(options)

        result_up_cmd = ex("instance_up_cmd", options)

        result_up_cmd && result_up_cmd[:exit_code] == 0
      end
    end

    def verify_instance_up(options = {})
      website, website_location = get_website_fields(options)
      is_up = false

      begin
        t_started = Time.now
        max_build_duration = website.max_build_duration

        while Time.now - t_started < max_build_duration
          is_up = instance_up?(options)
          break if is_up
        end
      rescue => ex
        Rails.logger.info("Issue to verify instance up #{ex}")
        is_up = false
      end

      website.valid = is_up
      website.http_port_available = is_up
      website.save!
    end

    def port_info_for_new_deployment(website_location)
      if website_location.running_port == website_location.port
        {
          port: website_location.second_port,
          attribute: "second_port",
          suffix_container_name: "--2"
        }
      else
        {
          port: website_location.port,
          attribute: "port",
          suffix_container_name: ""
        }
      end
    end

  	protected
  	def ex(cmd, options = {})
      Rails.logger.info("Deployment Method ex #{cmd}, options=#{options.inspect}")
      result = nil

      max_trials = options[:retry] ? options[:retry][:nb_max_trials] : 1

      (1..max_trials).each do |trial_i|
        Rails.logger.info("Execute #{cmd} trial ##{trial_i}")
        result = self.runner.execute([{ cmd_name: cmd, options: options }]).first

        if options[:ensure_exit_code].present?
          if result && result[:exit_code] != options[:ensure_exit_code]
            self.error!("Failed to run #{cmd}, result=#{result.inspect}")
          end
        end

        break if result && result[:exit_code] == 0

        if options[:retry]
          Rails.logger.info("Waiting for #{options[:retry][:interval_between_trials]}")
          sleep options[:retry][:interval_between_trials]
        end

        if options[:retry] && trial_i == options[:retry][:nb_max_trials]
          self.error!("Max trial reached (#{options[:retry][:nb_max_trials]})... terminating")
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

    def get_website_fields(options = {})
      assert options[:website]
      assert options[:website_location]

      [options[:website], options[:website_location]]
    end

    def get_website_fields(options = {})
      assert options[:website]
      assert options[:website_location]

      [options[:website], options[:website_location]]
    end

  end

end