
module DeploymentMethod

  class DockerCompose < Base

    def initialize
    end

    def logs(options = {})
      container_id = options[:container_id]
      container_id = options[:website].container_id if options[:website]

      assert container_id
      require_fields([:nb_lines], options)

      "docker exec #{container_id} docker-compose logs --tail=#{options[:nb_lines]}"
    end

    def erase_repository_files(options = {})
      require_fields([:path], options)

      "rm -rf #{options[:path]}"
    end

    def self.default_docker_compose_file(opts = {})
      env_part =
        if opts[:with_env_file]
"    env_file:
      - /opt/app/.env"
        else
"    # env_file:
    # - /opt/app/.env"
        end

"version: '3'
services:
  www:
#{env_part}
    volumes:
      - .:/opt/app/
    ports:
      - '80:80'
    build:
      context: .
    restart: always
"
    end

  end

end
