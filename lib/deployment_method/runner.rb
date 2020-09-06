module DeploymentMethod
  class Runner
    attr_accessor :execution
    attr_reader :execution_method
    attr_reader :cloud_provider
    attr_accessor :hooks

    def initialize(type, cloud_type, configs = {})
      @type = type
      @cloud_type = cloud_type
      @configs = configs
      @website = @configs[:website]
      @website_location = @configs[:website_location]
      @execution_method = get_execution_method
      @cloud_provider = get_cloud_provider

      if @execution_method&.respond_to?('location')
        @execution_method.location = configs[:location]
      end
    end

    def init_execution!(type, args = {})
      self.execution = Execution.create!(
        website: @website,
        website_location_id: @website_location&.id,
        status: Execution::STATUS_RUNNING,
        type: type,
        parent_execution_id: args['parent_execution_id']
      )

      execution.status = Execution::STATUS_SUCCESS
      execution.save
    end

    def get_execution_method
      dep_method = @configs[:execution_method]

      dep_method ||= case @type
                     when 'docker'
                       DeploymentMethod::DockerCompose.new
                     when 'kubernetes'
                       DeploymentMethod::Kubernetes.new
      end

      # for convenience, to call back the runner from any dep method
      set_execution_method(dep_method)
    end

    def set_execution_method(exec_method)
      exec_method.runner = self if exec_method
      @execution_method = exec_method

      @execution_method
    end

    def get_cloud_provider
      provider_type =
        case @cloud_type
        when 'cloud' # refactor to internal
          'internal'
        else
          @cloud_type
        end

      CloudProvider::Manager.instance.first_of_type(provider_type)
    end

    def multi_steps
      execution.status = Deployment::STATUS_RUNNING
      execution.save

      self
    end

    def terminate
      # will close the SSH connection if any

      @ssh&.close
      @ssh = nil
    end

    def ssh_configs
      {
        host: @configs[:host],
        user: @configs[:secret][:user],
        password: @configs[:secret][:password],
        private_key: @configs[:secret][:private_key]
      }
    end

    def record_execution_steps(results)
      execution.save_steps(results)
    end

    def execute(cmds, options = {})
      init_execution!(options[:execution_type] || 'Task') if !execution || options[:execution_type]

      protocol = @cloud_provider.deployment_protocol
      time_begin = Time.zone.now

      cmds.each do |cmd|
        cmd[:options] ||= {}
        cmd[:options][:website] ||= @website if @website
        cmd[:options][:website_location] ||= @website_location if @website_location
      end

      results = send("execute_#{protocol}", cmds)

      Rails.logger.info("Execute cmds=#{cmds.to_yaml}, result=#{results.to_yaml}, " \
        "duration=#{Time.zone.now - time_begin}")

      record_execution_steps(results) unless options[:skip_result_storage]

      results
    end

    def upload(local_path, remote_path)
      files = [{
        local_file_path: local_path,
        remote_file_path: remote_path
      }]
      Remote::Sftp.transfer(files, ssh_configs)
    end

    def upload_content_to(content, remote_path)
      files = [{
        content: content,
        remote_file_path: remote_path
      }]
      Remote::Sftp.transfer(files, ssh_configs)
    end

    def notify_for_hooks(level, given_result)
      self.hooks = @execution_method.hooks if @execution_method

      hooks.each do |hook|
        result = hook.call(level, given_result)

        if result
          given_result[:update] = result if given_result.class == Hash
          @execution_method.notify(level, result)
        end
      rescue StandardError => e
        Ex::Logger.info(e, 'Issue logging hook')
      end
    end

    def execute_raw_ssh(cmd)
      @ssh ||= Remote::Ssh.new(ssh_configs)

      @ssh.exec([cmd])
    end

    def execute_ssh(cmds)
      results = []

      generated_commands = cmds.map do |cmd|
        notify_for_hooks('info',
                         clone_and_set_cmd_state({ cmd_name: cmd[:cmd_name] }, 'before'))

        result = @execution_method.send(cmd[:cmd_name], cmd[:options])

        if cmd[:options][:is_complex]
          current_complex_cmd_result = {
            cmd_name: cmd[:cmd_name],
            result: 'done'
          }

          notify_for_hooks('info',
                           clone_and_set_cmd_state(current_complex_cmd_result, 'after'))

          results << current_complex_cmd_result

          # ret nil to skip it as a remote cmd
          nil
        else
          # it's the command to execute remotely:
          {
            cmd_name: cmd[:cmd_name],
            result: result
          }
        end
      end
                               .select(&:present?)

      unless generated_commands.empty?
        @ssh ||= Remote::Ssh.new(ssh_configs)

        # notify the before for each command
        generated_commands.each do |gen_cmd|
          notify_for_hooks('info', clone_and_set_cmd_state(gen_cmd, 'before'))
        end

        results_generated_commands = @ssh.exec(generated_commands.map { |c| c[:result] })

        results += generated_commands.map.with_index(0) do |gen_cmd, index|
          current_result = {
            cmd_name: gen_cmd[:cmd_name],
            result: results_generated_commands[index]
          }

          # notify after also
          notify_for_hooks('info', clone_and_set_cmd_state(current_result, 'after'))

          current_result
        end
      end

      results
    end

    protected

    def clone_and_set_cmd_state(obj, cmd_state)
      result = obj.clone
      result[:cmd_state] = cmd_state

      result
    end
  end
end
