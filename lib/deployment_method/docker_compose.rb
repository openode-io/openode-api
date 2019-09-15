
module DeploymentMethod

  class DockerCompose

    def initialize
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
