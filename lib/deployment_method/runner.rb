
module DeploymentMethod
  class Runner
    def initialize(type, cloud_type, configs = {})
      @type = type
      @cloud_type = cloud_type
      @configs = configs
      @deployment_method = self.get_deployment_method()
      @cloud_provider = self.get_cloud_provider()
    end

    def execute(cmds)
      protocol = @cloud_provider.deployment_protocol
      self.send("execute_#{protocol}", cmds)
    end

    def execute_ssh(cmds)
      generated_commands = cmds.map do |cmd|
        @deployment_method.send(cmd[:cmd_name], cmd[:options])
      end

      Remote::Ssh.exec(generated_commands, {
        host: @configs[:host],
        user: @configs[:secret][:user],
        password: @configs[:secret][:password],
        private_key: @configs[:secret][:private_key]
      })
    end

    def get_deployment_method()
      case @type
      when "docker"
        DeploymentMethod::DockerCompose.new
      else
        nil
      end
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
