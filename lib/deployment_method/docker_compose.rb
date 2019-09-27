
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

    def get_file(options = {})
      assert options[:repo_dir]
      assert options[:file]

      "cat #{options[:repo_dir]}#{options[:file]}"
    end

    def pre_repository_verification(options = {})
      assert options[:website]
      website, = options.values_at(:website)

      docker_compose_content = self.ex_stdout("get_file", { 
        repo_dir: website.repo_dir, file: "docker-compose.yml" 
      })

      DockerCompose.validate_docker_compose!(docker_compose_content)
    end

    def custom_cmd(options = {})
      require_fields([:website, :service, :cmd], options)
      website, service, cmd = options.values_at(:website, :service, :cmd)

      "#{self.exec_begin(website.container_id)} #{service} #{cmd}"
    end

    def erase_repository_files(options = {})
      require_fields([:path], options)

      "rm -rf #{options[:path]}"
    end

    def delete_files(options = {})
      require_fields([:files], options)

      options[:files]
        .map { |file| "rm -rf \"#{file}\" ; " }
        .join('')
    end

    def files_listing(options = {})
      require_fields([:path], options)
      path = options[:path]

      remote_js = "'use strict';; " +
        "const lfiles  = require('./lfiles');; " +
        "const result = lfiles.filesListing('#{path}', '#{path}');; " +
        "console.log(JSON.stringify(result));"
      
        "cd #{REMOTE_PATH_API_LIB} && " +
        "node -e \"#{remote_js}\""
    end

    def ensure_remote_repository(options = {})
      require_fields([:path], options)
      "mkdir -p #{options[:path]}"
    end

    def uncompress_remote_archive(options = {})
      require_fields([:archive_path, :repo_dir], options)
      arch_path = options[:archive_path]
      repo_dir = options[:repo_dir]

      "cd #{repo_dir} ; " +
      "unzip -o #{arch_path} ; " +
      "rm -f #{arch_path} ;" +
      "chmod -R 755 #{repo_dir}"
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

    def self.validate_docker_compose!(docker_compose_str)
      yml_docker_compose = YAML.load(docker_compose_str)

      if ! yml_docker_compose || ! yml_docker_compose["services"]
        return
      end

      yml_docker_compose["services"].each do |service_name, service|
        if service.keys.include?("privileged")
          raise ApplicationRecord::ValidationError.new("privileged now allowed")
        end
      end
    end

    protected
    def exec_begin(container_id)
      "docker exec #{container_id} docker-compose exec -T "
    end
  end
end
