
module DeploymentMethod
  class Runner
    attr_accessor :deployment

    def initialize(type, cloud_type, configs = {})
      @type = type
      @cloud_type = cloud_type
      @configs = configs
      @website = @configs[:website]
      @website_location = @configs[:website_location]
      @deployment_method = self.get_deployment_method()
      @cloud_provider = self.get_cloud_provider()

      self.deployment = Deployment.create!({
        website: @website,
        website_location: @website_location,
        status: Deployment::STATUS_RUNNING
      })
    end

    def deployment_method
      @deployment_method
    end

    def cloud_provider
      @cloud_provider
    end

    def terminate
      # will close the SSH connection if any
      @ssh.close if @ssh
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

    def record_deployment_steps(results)
      self.deployment.save_steps(results)
    end

    def execute(cmds)
      protocol = @cloud_provider.deployment_protocol
      time_begin = Time.now

      cmds.each do |cmd|
        cmd[:options] ||= {}
        cmd[:options][:website] ||= @website if @website
        cmd[:options][:website_location] ||= @website_location if @website_location
      end

      results = self.send("execute_#{protocol}", cmds)

      Rails.logger.info("Execute cmds=#{cmds.to_yaml}, result=#{results.to_yaml}, " +
        "duration=#{Time.now - time_begin}")

      record_deployment_steps(results)

      results
    end

    def upload(local_path, remote_path)
      files = [{
        local_file_path: local_path,
        remote_file_path: remote_path
      }]
      Remote::Sftp.transfer(files, self.ssh_configs)
    end

    def upload_content_to(content, remote_path)
      files = [{
        content: content,
        remote_file_path: remote_path
      }]
      Remote::Sftp.transfer(files, self.ssh_configs)
    end

    def execute_ssh(cmds)
      results = []

      generated_commands = cmds.map do |cmd|
        result = @deployment_method.send(cmd[:cmd_name], cmd[:options])

        if cmd[:options][:is_complex]
          results << {
            cmd_name: cmd[:cmd_name],
            result: 'done'
          }

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
      .select { |gen_cmd| gen_cmd.present? }

      if generated_commands.length > 0
        @ssh ||= Remote::Ssh.new(self.ssh_configs)
        results_generated_commands = @ssh.exec(generated_commands.map { |c| c[:result] })

        results = results + 
          generated_commands.map.with_index(0) do |gen_cmd, index|
            {
              cmd_name: gen_cmd[:cmd_name],
              result: results_generated_commands[index]
            }
          end
      end

      results
    end

    def get_deployment_method()
      dep_method = case @type
      when "docker"
        DeploymentMethod::DockerCompose.new
      else
        nil
      end

      # for convenience, to call back the runner from any dep method
      dep_method.runner = self if dep_method

      dep_method
    end

    def get_cloud_provider()
      provider_type =
      case @cloud_type
      when "cloud" # refactor to internal
        "internal"
      when "private-cloud"
        "vultr"
      else
        @cloud_type
      end

      CloudProvider::Manager.instance.first_of_type(provider_type)
    end

    private
  end
end
