module DeploymentMethod
  class Base
    RuntimeError = Class.new(StandardError)

    attr_accessor :runner

    REMOTE_PATH_API_LIB = '/root/openode-www/api/lib'
    DEFAULT_CRONTAB_FILENAME = '.openode.cron'

    def error!(msg)
      Rails.logger.error(msg)
      raise msg
    end

    def verify_can_deploy(options = {})
      website, website_location = get_website_fields(options)

      can_deploy, msg = website.can_deploy_to?(website_location)

      raise ApplicationRecord::ValidationError, msg unless can_deploy
    end

    def mark_accessed(options = {})
      assert options[:website]
      website = options[:website]
      website.last_access_at = Time.zone.now
      website.save
    end

    def initialization(options = {})
      website, website_location = get_website_fields(options)

      mark_accessed(options)
      website.change_status!(Website::STATUS_STARTING)
      website_location.allocate_ports!
    end

    def launch(_options = {})
      raise 'must be implemented in child class'
    end

    def stop(options = {})
      website, = get_website_fields(options)

      # stop based on the deployment method (ex. docker compose)
      runner.deployment_method.do_stop(options)

      # stop based on the cloud provider
      runner.cloud_provider.stop(options)

      website.change_status!(Website::STATUS_OFFLINE)
    end

    def instance_up_cmd(options = {})
      require_fields([:website_location], options)
      website_location = options[:website_location]

      port_info = port_info_for_new_deployment(website_location)
      url = "http://localhost:#{port_info[:port]}/"

      "curl --insecure --max-time 15 --connect-timeout 5 #{url} "
    end

    def node_available?(_options = {})
      raise 'node_available? must be defined in the child class'
    end

    def instance_up?(options = {})
      website = options[:website]
      website_location = options[:website_location]

      if website.skip_port_check?
        node_available?(options)
      else
        return false unless node_available?(options)

        result_up_cmd = ex('instance_up_cmd', website_location: website_location)

        result_up_cmd && (result_up_cmd[:exit_code]).zero?
      end
    end

    def verify_instance_up(options = {})
      website, = get_website_fields(options)
      is_up = false

      begin
        t_started = Time.zone.now
        max_build_duration = website.max_build_duration

        while Time.zone.now - t_started < max_build_duration
          Rails.logger.info('deployment duration ' \
            "#{Time.zone.now - t_started}/#{max_build_duration}")

          is_up = instance_up?(options)
          break if is_up
          break if ENV['RAILS_ENV'] == 'test'

          sleep 2
        end

        error!("Max build duration reached (#{max_build_duration})") unless is_up
      rescue StandardError => e
        Ex::Logger.info(e, 'Issue to verify instance up')
        is_up = false
      end

      website.valid = is_up
      website.http_port_available = is_up
      website.save!
      website.change_status!(Website::STATUS_ONLINE) if is_up
    end

    def port_info_for_new_deployment(website_location)
      if website_location.running_port == website_location.port
        {
          port: website_location.second_port,
          attribute: 'second_port',
          suffix_container_name: '--2',
          name: "#{website_location.website.user_id}--" \
            "#{website_location.website.site_name}--2"
        }
      else
        {
          port: website_location.port,
          attribute: 'port',
          suffix_container_name: '',
          name: "#{website_location.website.user_id}--" \
            "#{website_location.website.site_name}"
        }
      end
    end

    def finalize(options = {})
      website, website_location = get_website_fields(options)
      website.reload
      website_location.reload

      port_info = port_info_for_new_deployment(website_location)

      if website.online?
        website_location.running_port = port_info[:port]
      else
        website.change_status!(Website::STATUS_OFFLINE)
        website_location.running_port = nil
      end

      if runner.andand.execution
        runner.execution.status = if website.online?
                                    Execution::STATUS_SUCCESS
                                  else
                                    Execution::STATUS_FAILED
        end

        runner.execution.save
      end

      website_location.save
    end

    protected

    def ex(cmd, options = {})
      Rails.logger.info("Deployment Method ex #{cmd}, options=#{options.inspect}")
      result = nil

      max_trials = options[:retry] ? options[:retry][:nb_max_trials] : 1

      (1..max_trials).each do |trial_i|
        Rails.logger.info("Execute #{cmd} trial ##{trial_i}")
        result = runner.execute([{ cmd_name: cmd, options: options }]).first[:result]

        if options[:ensure_exit_code].present?
          if result && result[:exit_code] != options[:ensure_exit_code]
            error!("Failed to run #{cmd}, result=#{result.inspect}")
          end
        end

        break if result && (result[:exit_code]).zero?

        if options[:retry]
          Rails.logger.info("Waiting for #{options[:retry][:interval_between_trials]}")
          sleep options[:retry][:interval_between_trials]
        end

        if options[:retry] && trial_i == options[:retry][:nb_max_trials]
          error!("Max trial reached (#{options[:retry][:nb_max_trials]})... terminating")
        end
      end

      result
    end

    def ex_stdout(cmd, options = {})
      runner.execute([{ cmd_name: cmd, options: options }]).first[:result][:stdout]
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
  end
end
