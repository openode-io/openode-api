module DeploymentMethod
  class Base
    RuntimeError = Class.new(StandardError)

    attr_accessor :runner

    REMOTE_PATH_API_LIB = '/root/openode-www/api/lib'
    DEFAULT_CRONTAB_FILENAME = '.openode.cron'

    def error!(msg)
      Rails.logger.error(msg)
      notify('error', msg)
      raise msg
    end

    def save_extra_execution_attrib(attrib_name, value)
      runner.execution&.save_extra_attrib!(attrib_name, value)
    end

    def store_remote_file(name, content)
      current_secret = runner.execution.secret || {}

      current_secret[name] = content

      runner.execution.save_secret!(current_secret)
    end

    def verify_can_deploy(options = {})
      website, website_location = get_website_fields(options)

      can_deploy, msg = website.can_deploy_to?(website_location)

      raise ApplicationRecord::ValidationError, msg unless can_deploy
    end

    def notify(level, msg)
      event = {
        'status': runner.execution&.status,
        'level': level,
        'update': Str::Encode.strip_invalid_chars(msg)
      }

      DeploymentsChannel.broadcast_to(runner.execution, event)

      if runner.execution
        runner.execution.reload
        runner.execution.events ||= []
        runner.execution.events << event
        runner.execution.save
      end
    end

    def mark_accessed(options = {})
      assert options[:website]
      website = options[:website]
      website.last_access_at = Time.zone.now
      website.save
    end

    # file SYNC
    def files_listing(options = {})
      require_fields([:path], options)
      path = options[:path]

      remote_js = "'use strict';; " \
                  "const lfiles  = require('./lfiles');; " \
                  "const result = lfiles.filesListing('#{path}', '#{path}');; " \
                  'console.log(JSON.stringify(result));'

      "cd #{REMOTE_PATH_API_LIB} && " \
        "node -e \"#{remote_js}\""
    end

    def clear_repository(options = {})
      require_fields([:website], options)

      "rm -rf #{options[:website].repo_dir}"
    end

    def erase_repository_files(options = {})
      require_fields([:path], options)

      "rm -rf #{options[:path]}"
    end

    def ensure_remote_repository(options = {})
      require_fields([:path], options)
      "mkdir -p #{options[:path]}"
    end

    def delete_files(options = {})
      require_fields([:files], options)

      options[:files]
        .map { |file| "rm -rf \"#{file}\" ; " }
        .join('')
    end

    def uncompress_remote_archive(options = {})
      require_fields(%i[archive_path repo_dir], options)
      arch_path = options[:archive_path]
      repo_dir = options[:repo_dir]

      "cd #{repo_dir} ; " \
        "unzip -o #{arch_path} ; " \
        "rm -f #{arch_path} ;" \
        "chmod -R 755 #{repo_dir}"
    end
    # end SYNC

    def initialization(options = {})
      website, = get_website_fields(options)

      mark_accessed(options)
      website.change_status!(Website::STATUS_STARTING, skip_validations: true)
    end

    def send_crontab(options = {})
      assert options[:website]
      website = options[:website]

      if website.crontab.present?
        Rails.logger.info('updating crontab')
        runner.upload_content_to(website.crontab,
                                 "#{website.repo_dir}#{Base::DEFAULT_CRONTAB_FILENAME}")
      else
        Rails.logger.info('skipping crontab update (empty)')
      end
    end

    def launch(_options = {})
      raise 'must be implemented in child class'
    end

    def begin_stop(website)
      raise "Already stopping" if website.reload.stopping?

      website.change_status!(Website::STATUS_STOPPING, skip_validations: true)
    end

    def stop(options = {})
      website, = get_website_fields(options)

      begin_stop(website)

      begin
        # stop based on the deployment method (ex. docker compose)
        runner.execution_method.do_stop(options)
      rescue StandardError => e
        Ex::Logger.error(e, "Issue to stop the instance #{website.site_name}")
      end

      # stop based on the cloud provider
      runner.cloud_provider.stop(options)

      website.change_status!(Website::STATUS_OFFLINE, skip_validations: true)
    end

    def instance_up_cmd(_options = {})
      raise 'instance_up_cmd must be defined in the child class'
    end

    def node_available?(_options = {})
      raise 'node_available? must be defined in the child class'
    end

    def instance_up?(options = {})
      website = options[:website]
      website_location = options[:website_location]

      Rails.logger.info("instance_up? for #{website.site_name}")

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

          sleep 7
        end

        error!("Max build duration reached (#{max_build_duration})") unless is_up
      rescue StandardError => e
        Ex::Logger.info(e, 'Issue to verify instance up')
        is_up = false
      end

      website.valid = is_up
      website.http_port_available = is_up
      website.save!
      website.change_status!(Website::STATUS_ONLINE, skip_validations: true) if is_up
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
        website.change_status!(Website::STATUS_OFFLINE, skip_validations: true)
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

    def final_instance_details(opts = {})
      result = {}

      website, website_location = get_website_fields(opts)

      result['result'] = 'success'
      result['url'] = "http://#{website_location.main_domain}/"

      if website.domain_type == 'custom_domain'
        result['NS Records (Nameservers)'] = ['ns1.vultr.com', 'ns2.vultr.com']
        result['A Record'] = website_location.location_server.ip
      end

      result
    end

    def notify_or_soft_log(msg, skip_notify_errors)
      if skip_notify_errors
        Rails.logger.error(msg)
      else
        error!(msg)
      end
    end

    def ex(cmd, options = {})
      Rails.logger.info("Deployment Method ex #{cmd}, options=#{options.inspect}")
      result = nil

      if options[:default_retry_scheme]
        options[:retry] = {
          nb_max_trials: Rails.env.test? ? 1 : 3,
          interval_between_trials: 2
        }
      end

      max_trials = options[:retry] ? options[:retry][:nb_max_trials] : 1

      (1..max_trials).each do |trial_i|
        Rails.logger.info("Execute #{cmd} trial ##{trial_i}")
        result = runner.execute([{ cmd_name: cmd, options: options }]).first[:result]

        if options[:ensure_exit_code].present?
          if result && result[:exit_code] != options[:ensure_exit_code]
            msg = "Failed to run #{cmd}, result=#{result.inspect}"
            notify_or_soft_log(msg, options[:skip_notify_errors])
          end
        end

        break if result && (result[:exit_code]).zero?

        if options[:retry]
          Rails.logger.info("Waiting for #{options[:retry][:interval_between_trials]}")
          sleep options[:retry][:interval_between_trials] unless Rails.env.test?
        end

        if options[:retry] && trial_i == options[:retry][:nb_max_trials]
          msg = "Max trial reached (#{options[:retry][:nb_max_trials]})... terminating"
          notify_or_soft_log(msg, options[:skip_notify_errors])
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
