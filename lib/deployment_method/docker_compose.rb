# frozen_string_literal: true

module DeploymentMethod
  class DockerCompose < Base
    EXTRA_MANAGEMENT_RAM = 250 # MB

    def initialize; end

    # verify can deploy

    def verify_can_deploy(options = {})
      super(options)

      pre_repository_verification(options)
    end

    def pre_repository_verification(options = {})
      assert options[:website]
      website, = options.values_at(:website)

      docker_compose_content = ex_stdout('get_file',
                                         repo_dir: website.repo_dir, file: 'docker-compose.yml')

      DockerCompose.validate_docker_compose!(docker_compose_content)
    end

    def self.validate_docker_compose!(docker_compose_str)
      yml_docker_compose = YAML.safe_load(docker_compose_str)

      return if !yml_docker_compose || !yml_docker_compose['services']

      yml_docker_compose['services'].each do |_service_name, service|
        if service.keys.include?('privileged')
          raise ApplicationRecord::ValidationError, 'privileged now allowed'
        end
      end
    end

    # initialization

    def initialization(options = {})
      super(options)

      ex_stdout('prepare_dind_compose_image')
      send_crontab(options)
    end

    def prepare_dind_compose_image(_options = {})
      base_server_files_path = '/root/openode-www/'

      "docker build -f #{base_server_files_path}deployment/dind-with-docker-compose/Dockerfile " \
        ' -t dind-with-docker-compose .'
    end

    def send_crontab(options = {})
      assert options[:website]
      website = options[:website]

      if website.crontab.present?
        Rails.logger.info('updating crontab')
        @runner.upload_content_to(website.crontab, "#{website.repo_dir}#{Base::DEFAULT_CRONTAB_FILENAME}")
      else
        Rails.logger.info('skipping crontab update (empty)')
      end
    end

    # launch

    def launch(options = {})
      website, website_location = get_website_fields(options)
      require_fields([:limit_resources], options)
      limit_resources = options[:limit_resources]

      port_info = port_info_for_new_deployment(website_location)

      # make sure to kill the container on target port
      kill_global_containers_by(ports: [port_info[:port]], names: [port_info[:name]])

      options_front_container = {
        in_port: 80,
        website: website,
        website_location: website_location,
        ensure_exit_code: 0,
        limit_resources: limit_resources
      }

      ex('front_container', options_front_container)

      front_container = find_containers_by(ports: [port_info[:port]]).first

      if !front_container || !front_container[:ID]
        error!("Can't find the built container... exiting.")
      end

      Rails.logger.info("Front container for #{website.site_name} is #{front_container.inspect}")

      sleep 2 if ENV['RAILS_ENV'] != 'test'

      options_docker_compose = {
        front_container_id: front_container[:ID],
        retry: {
          nb_max_trials: 15,
          interval_between_trials: 2
        }
      }

      ex('docker_compose', options_docker_compose)

      website.container_id = front_container[:ID]
      website.save!
    end

    # must be run independently (single step)
    def finalize(options = {})
      website, website_location = get_website_fields(options)
      super(options)
      website.reload

      # remove the dead containers
      ports_to_remove =
        [website_location.port, website_location.second_port] - [website_location.running_port]

      kill_global_containers_by(ports: ports_to_remove)

      # TODO: add dock compose logs
    end

    # stop
    def do_stop(options = {})
      website, website_location = get_website_fields(options)

      kill_global_containers_by(ports: website_location.ports)
    end

    # reload
    def reload(options = {})
      website, website_location = get_website_fields(options)

      docker_compose_options = { front_container_id: website.container_id }

      ex('down', docker_compose_options)
      ex('docker_compose', docker_compose_options)
    end

    def front_crontainer_name(options = {})
      assert options[:website]
      assert options[:port_info]
      website, port_info = options.values_at(:website, :port_info)

      "#{website.user_id}--#{website.site_name}#{port_info[:suffix_container_name]}"
    end

    def front_container(options = {})
      assert options[:in_port]
      website, website_location = get_website_fields(options)

      port_info = port_info_for_new_deployment(website_location)
      plan = website.plan

      resources = if !options[:limit_resources]
                    ''
                  else
                    " -m #{plan[:ram] + EXTRA_MANAGEMENT_RAM}MB --cpus=#{website_location.nb_cpus || 1} "
      end

      "docker run -w=/opt/app/ -d -v #{website.repo_dir}:/opt/app/ " \
        "--name #{front_crontainer_name(website: website, port_info: port_info)} " \
        "-p 127.0.0.1:#{port_info[:port]}:#{options[:in_port]} " \
        "#{resources} --privileged dind-with-docker-compose:latest"
    end

    def docker_compose(options = {})
      assert options[:front_container_id]

      "docker exec #{options[:front_container_id]} docker-compose up -d"
    end

    def down(options = {})
      assert options[:front_container_id]

      "docker exec #{options[:front_container_id]} docker-compose down"
    end

    def ps(options = {})
      assert options[:front_container_id]

      "docker exec #{options[:front_container_id]} docker-compose ps"
    end

    def node_available?(options = {})
      assert options[:website]
      website = options[:website]

      options_ps = {
        front_container_id: website.container_id
      }

      result = ex('ps', options_ps)

      result && result[:exit_code] == 0 && result[:stdout].include?('Up') &&
        result[:stdout].include?('80->80')
    end

    def global_containers(_options = {})
      'docker ps -a --format ' \
        '"{{.ID}};{{.Image}};{{.Command}};{{.CreatedAt}};{{.RunningFor}};{{.Ports}};' \
        '{{.Status}};{{.Size}};{{.Names}};{{.Labels}};{{.Mounts}}"'
    end

    def parse_global_containers(_options = {})
      containers_list = ex_stdout('global_containers')

      containers_list
        .split("\n")
        .map do |line|
          if !line
            nil
          elsif line.split(';').length != 11
            nil
          else
            parts = line.split(';')

            {
              ID: parts[0],
              Image: parts[1],
              Command: parts[2],
              CreatedAt: parts[3],
              RunningFor: parts[4],
              Ports: parts[5],
              Status: parts[6],
              Size: parts[7],
              Names: parts[8],
              Labels: parts[9],
              Mounts: parts[10]
            }
          end
        end
        .select(&:present?)
    end

    def find_containers_by(options = {})
      ports = options[:ports] || []
      names = options[:names] || []

      str_ports_to_find = ports.map { |port| ":#{port}->" }

      parse_global_containers
        .select do |container|
        container && (
          str_ports_to_find.any? { |s| container[:Ports].include?(s) } ||
          names.any? { |s| container[:Names].include?(s) }
        )
      end
    end

    def kill_global_container(options = {})
      assert options[:id]
      id = options[:id]

      "docker exec #{id} docker-compose down ; docker rm -f #{id}"
    end

    def kill_global_containers_by(options = {})
      ports = options[:ports]
      name = options[:name]
      assert name || ports

      containers = find_containers_by(options)

      containers.map do |container|
        ex_stdout('kill_global_container',
                  id: container[:ID])
      end
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

    def custom_cmd(options = {})
      require_fields(%i[website service cmd], options)
      website, service, cmd = options.values_at(:website, :service, :cmd)

      "#{exec_begin(website.container_id)} #{service} #{cmd}"
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

      remote_js = "'use strict';; " \
                  "const lfiles  = require('./lfiles');; " \
                  "const result = lfiles.filesListing('#{path}', '#{path}');; " \
                  'console.log(JSON.stringify(result));'

      "cd #{REMOTE_PATH_API_LIB} && " \
        "node -e \"#{remote_js}\""
    end

    def ensure_remote_repository(options = {})
      require_fields([:path], options)
      "mkdir -p #{options[:path]}"
    end

    def clear_repository(options = {})
      require_fields([:website], options)

      "rm -rf #{options[:website].repo_dir}"
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

    protected

    def exec_begin(container_id)
      "docker exec #{container_id} docker-compose exec -T "
    end
  end
end
