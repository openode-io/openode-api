require 'droplet_kit'

module DeploymentMethod
  module Util
    module ImageRegistryImpl
      class DigitalOcean < Base
        def do_client
          assert ENV['DO_ACCESS_TOKEN']

          @client ||= DropletKit::Client.new(access_token: ENV['DO_ACCESS_TOKEN'])
        end

        def initialize(args = {})
          assert args[:registry_name]
          super(args)
        end

        def repositories
          do_client.container_registry_repository.all(
            registry_name: opts[:registry_name]
          )
        end

        def tags(repository_name)
          do_client.container_registry_repository.tags(
            registry_name: opts[:registry_name], repository: repository_name
          )
        end

        def destroy_tag(repository_name, tag_name)
          do_client.container_registry_repository.delete_tag(
            registry_name: opts[:registry_name],
            repository: repository_name,
            tag: tag_name
          )
        end
      end
    end
  end
end
