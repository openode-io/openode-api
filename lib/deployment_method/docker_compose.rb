module DeploymentMethod
  class DockerCompose < Base
    EXTRA_MANAGEMENT_RAM = 250 # MB

    def initialize; end

    # verify can deploy

    def verify_can_deploy(options = {})
      notify('warn', "*** DEPRECATION WARNING - you are using a deployment " \
                      "method which will get deprecated. " \
                      "Make sure to upgrade the CLI (npm -g i openode) " \
                      "and run openode set-config TYPE kubernetes. " \
                      "See http://www.openode.io/docs/installation/upgrade.md " \
                      "for more information.")

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
      website_location = options[:website_location]
      super(options)

      website_location.allocate_ports!

      ex_stdout('prepare_dind_compose_image')
      send_crontab(options)
    end

    def prepare_dind_compose_image(_options = {})
      base_server_files_path = '/root/openode-www/'

      "docker build -f #{base_server_files_path}deployment/dind-with-docker-compose/Dockerfile " \
        ' -t dind-with-docker-compose .'
    end

    def send_crontab(options = {})
      super(options)
    end

    # launch

    def launch(options = {})
      website, website_location = get_website_fields(options)

      raise 'missing limit resource' unless [true, false].include?(options[:limit_resources])

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
          interval_between_trials: 10
        }
      }

      ex('docker_compose', options_docker_compose)

      website.container_id = front_container[:ID]
      website.save!
    end

    def notify_final_instance_details(opts = {})
      get_website_fields(opts)
      final_details = final_instance_details(opts)

      notify('info', details: final_details)
    end

    # must be run independently (single step)
    def finalize(options = {})
      website, website_location = get_website_fields(options)
      super(options)
      website.reload

      # logs
      begin
        ex_stdout('logs', website: website,
                          container_id: website.container_id,
                          nb_lines: 10_000)
      rescue StandardError => e
        Ex::Logger.info(e, 'Unable to retrieve the docker compose logs')
      end

      # remove the dead containers
      ports_to_remove =
        [website_location.port, website_location.second_port] - [website_location.running_port]

      kill_global_containers_by(ports: ports_to_remove)

      if website.online?
        notify_final_instance_details(options)
      end
    end

    # stop
    def do_stop(options = {})
      _, website_location = get_website_fields(options)

      kill_global_containers_by(ports: website_location.ports)
    end

    # reload
    def reload(options = {})
      website, = get_website_fields(options)

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
                    " -m #{plan[:ram] + EXTRA_MANAGEMENT_RAM}MB " \
                    "--cpus=#{website_location.nb_cpus || 1} "
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

    def instance_up_cmd(options = {})
      require_fields([:website_location], options)
      website_location = options[:website_location]

      port_info = port_info_for_new_deployment(website_location)
      url = "http://localhost:#{port_info[:port]}/"

      "curl --insecure --max-time 15 --connect-timeout 5 #{url} "
    end

    def node_available?(options = {})
      assert options[:website]
      website = options[:website]

      options_ps = {
        front_container_id: website.container_id
      }

      result = ex('ps', options_ps)

      result && (result[:exit_code]).zero? && result[:stdout].include?('Up') &&
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
      container_id = options[:website]&.container_id || options[:container_id]

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
      require_fields(%i[website app cmd], options)
      website, app, cmd = options.values_at(:website, :app, :cmd)

      "#{exec_begin(website.container_id)} #{app} #{cmd}"
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

    # the following hooks are notification procs.

    def self.hook_error
      proc do |level, msg|
        msg if level == 'error'
      end
    end

    def self.hook_cmd_is(obj, cmds_name)
      cmds_name.include?(obj&.dig(:cmd_name))
    end

    def self.hook_cmd_state_is(obj, cmd_state)
      obj&.dig(:cmd_state) == cmd_state
    end

    def self.hook_cmd_and_state(cmds_name, cmd_state, output)
      proc do |_, msg|
        if hook_cmd_is(msg, cmds_name) && hook_cmd_state_is(msg, cmd_state)
          output
        end
      end
    end

    def self.hook_verify_can_deploy
      DockerCompose.hook_cmd_and_state(['verify_can_deploy'], 'before',
                                       'Verifying allowed to deploy...')
    end

    def self.hook_verify_can_deploy_done
      DockerCompose.hook_cmd_and_state(['verify_can_deploy'], 'after',
                                       '...verified.')
    end

    def self.hook_initialization
      DockerCompose.hook_cmd_and_state(['initialization'], 'before',
                                       'Initializing the instance...')
    end

    def self.hook_initialization_done
      DockerCompose.hook_cmd_and_state(['initialization'], 'after',
                                       '...initialized.')
    end

    def self.hook_front_container
      DockerCompose.hook_cmd_and_state(['front_container'], 'before',
                                       'Building the ingress connection...')
    end

    def self.hook_docker_compose
      DockerCompose.hook_cmd_and_state(['docker_compose'], 'before',
                                       'Building the instance image...')
    end

    def self.hook_docker_compose_done
      DockerCompose.hook_cmd_and_state(['docker_compose'], 'after',
                                       '...instance image built.')
    end

    def self.hook_verify_instance_up
      DockerCompose.hook_cmd_and_state(%w[verify_instance_up instance_up_cmd],
                                       'before',
                                       'Verifying instance up...')
    end

    def self.hook_verify_instance_up_done
      DockerCompose.hook_cmd_and_state(['verify_instance_up'],
                                       'after',
                                       '...instance verification finished.')
    end

    def self.hook_finalize
      DockerCompose.hook_cmd_and_state(['finalize'],
                                       'before',
                                       'Finalizing...')
    end

    def self.hook_finalize_done
      DockerCompose.hook_cmd_and_state(['finalize'],
                                       'after',
                                       '...finalized.')
    end

    def self.hook_final_instance_details
      proc do |_, obj|
        if DockerCompose.hook_cmd_is(obj, 'final_instance_details')
          obj[:details]
        end
      end
    end

    def self.hook_logs
      proc do |_, msg|
        if hook_cmd_is(msg, ['logs']) && hook_cmd_state_is(msg, 'after')
          msg[:result][:stdout]
        end
      end
    end

    def hooks
      [
        DockerCompose.hook_error,
        DockerCompose.hook_verify_can_deploy,
        DockerCompose.hook_verify_can_deploy_done,
        DockerCompose.hook_initialization,
        DockerCompose.hook_front_container,
        DockerCompose.hook_docker_compose,
        DockerCompose.hook_docker_compose_done,
        DockerCompose.hook_verify_instance_up,
        DockerCompose.hook_verify_instance_up_done,
        DockerCompose.hook_finalize,
        DockerCompose.hook_finalize_done,
        DockerCompose.hook_final_instance_details,
        DockerCompose.hook_logs
      ]
    end

    protected

    def exec_begin(container_id)
      "docker exec #{container_id} docker-compose exec -T "
    end
  end
end
