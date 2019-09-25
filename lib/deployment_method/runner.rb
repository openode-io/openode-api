
module DeploymentMethod
  class Runner
    def initialize(type, cloud_type, configs = {})
      @type = type
      @cloud_type = cloud_type
      @configs = configs
      @deployment_method = self.get_deployment_method()
      @cloud_provider = self.get_cloud_provider()
    end

    def ssh_configs
      {
        host: @configs[:host],
        user: @configs[:secret][:user],
        password: @configs[:secret][:password],
        private_key: @configs[:secret][:private_key]
      }
    end

    def execute(cmds)
      protocol = @cloud_provider.deployment_protocol
      logs = self.send("execute_#{protocol}", cmds)

      Rails.logger.info("Execute cmds=#{cmds.inspect}, result=#{logs.inspect}")

      logs
    end

    def upload(local_path, remote_path)
      files = [{
        local_file_path: local_path,
        remote_file_path: remote_path
      }]
      Remote::Sftp.transfer(files, self.ssh_configs)
    end

    def execute_ssh(cmds)
      generated_commands = cmds.map do |cmd|
        result = @deployment_method.send(cmd[:cmd_name], cmd[:options])

        cmd[:options][:is_complex] ? nil : result
      end
      .select { |gen_cmd| gen_cmd.present? }

      if generated_commands.length > 0
        Remote::Ssh.exec(generated_commands, self.ssh_configs)
      else
        []
      end
    end

    def get_deployment_method()
      dep_method = case @type
      when "docker"
        DeploymentMethod::DockerCompose.new
      else
        nil
      end

      # for convenience, to call back the runner from any dep method
      dep_method.runner = self

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
