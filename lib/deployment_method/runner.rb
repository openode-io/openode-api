
module DeploymentMethod
  class Runner
    def initialize(type, cloud_type, configs = {})
      @type = type
      @cloud_type = cloud_type
      @configs = configs
      @deployment_method = self.get_deployment_method(type)
      @cloud_provider = self.get_cloud_provider(cloud_type)
    end

    def logs
    end

    private
    # TODO test
    def get_deployment_method(type)
      case type
      when "docker"
        DeploymentMethod::DockerCompose.new
      end
    end

    # TODO test
    def get_cloud_provider(cloud_type)
      case cloud_type
      when "cloud" # refactor to internal

      end
    end
  end
end
