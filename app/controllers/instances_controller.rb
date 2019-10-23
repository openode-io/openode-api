# frozen_string_literal: true

class InstancesController < ApplicationController
  MINIMUM_CLI_VERSION = '2.0.14'

  before_action :authorize
  before_action :populate_website
  before_action except: [:add_location] do
    populate_website_location
  end
  before_action :prepare_runner
  after_action :terminate_runner

  before_action only: [:restart] do
    requires_minimum_cli_version
  end

  before_action :check_minimum_cli_version
  after_action :record_website_event

  before_action only: %i[logs cmd reload] do
    requires_status_in [Website::STATUS_ONLINE]
  end

  before_action only: [:restart] do
    requires_status_in [Website::STATUS_ONLINE, Website::STATUS_OFFLINE]
  end

  before_action only: [:set_cpus] do
    requires_paid_instance
  end

  before_action only: [:set_cpus] do
    requires_cloud_plan
  end

  def index
    json(@user.websites)
  end

  def show
    json(@website)
  end

  def destroy
    @website.website_locations.each do |website_location|
      runner = website_location.prepare_runner

      runner.execute([
                       { cmd_name: 'stop', options: { is_complex: true } },
                       { cmd_name: 'clear_repository' }
                     ])
    end

    @website.destroy

    json(result: 'success')
  end

  def plan
    json(@website.plan)
  end

  def plans
    json(@website_location.available_plans)
  end

  def set_plan
    plan_id = params['plan']

    all_plans = @website_location.available_plans
    plan = all_plans.find { |p| [p[:id], p[:internal_id]].include?(plan_id) }

    validation_error!('Unavailable plan') unless plan

    @website.change_plan!(plan[:internal_id])

    @website_event_obj = { title: 'change-plan', new_value: plan[:id], original_value: @website.account_type }

    @runner.delay.execute([{ cmd_name: 'stop', options: { is_complex: true } }])

    json(result: 'success', msg: 'Instance will stop, make sure to redeploy it')
  end

  def set_cpus
    @website_location.nb_cpus = params['nb_cpus'].to_i
    @website_location.save!

    @website_event_obj = { title: 'change-nb-cpus', nb_cpus: @website_location.nb_cpus }

    # redeploy
    DeploymentMethod::Deployer.delay.run(@website_location, @runner)

    json(result: 'success')
  end

  def changes
    validation_error!('Missing files') unless params['files']
    files_client = JSON.parse(params['files'])
    files_server = JSON.parse(@runner.execute([
                                                { cmd_name: 'files_listing', options: { path: @website.repo_dir } }
                                              ]).first[:result][:stdout])

    changes = Io::Dir.diff(files_client, files_server, @website.normalized_storage_areas)

    @website_event_obj = { title: 'sync-changes', changes: changes }

    json(changes)
  end

  def send_compressed_file
    file = params['file'].tempfile
    local_file = file.path
    archive_filename = params['file'].original_filename
    remote_file = "#{@website.repo_dir}#{archive_filename}"

    raise 'bad remote file' unless Io::Path.secure?(@website.repo_dir, remote_file)

    @runner.execute([
                      { cmd_name: 'ensure_remote_repository', options: { path: @website.repo_dir } }
                    ])

    @runner.upload(local_file, remote_file)

    @runner.execute([
                      { cmd_name: 'uncompress_remote_archive',
                        options: { archive_path: remote_file, repo_dir: @website.repo_dir } }
                    ])

    json(result: 'success')
  end

  def delete_files
    assert params['filesInfo'].present?
    input_files =
      params['filesInfo'].class.name == 'String' ? JSON.parse(params['filesInfo']) : params['filesInfo']

    input_files = input_files.map { |file| "#{@website.repo_dir}#{file['path']}" }
    files = Io::Path.filter_secure(@website.repo_dir, input_files)

    @runner.execute([
                      {
                        cmd_name: 'delete_files', options: {
                          files: files
                        }
                      }
                    ])

    @website_event_obj = { title: 'delete-files', files: files }

    json(result: 'success')
  end

  def cmd
    assert params['cmd'].present?
    assert params['service'].present?

    result = @runner.execute([
                               {
                                 cmd_name: 'custom_cmd', options: {
                                   website: @website.clone,
                                   cmd: Io::Cmd.sanitize_input_cmd(params['cmd']),
                                   service: Io::Cmd.sanitize_input_cmd(params['service'])
                                 }
                               }
                             ]).first[:result]

    json(result: result)
  end

  def stop
    @runner.execute([{ cmd_name: 'stop', options: { is_complex: true } }])

    json(result: 'success')
  end

  def reload
    @runner.delay.execute([{ cmd_name: 'reload', options: { is_complex: true } }])
    @website_event_obj = { title: 'instance-reload' }

    json(result: 'success', msg: 'operation in progress')
  end

  def docker_compose
    content = if params['has_env_file']
                DeploymentMethod::DockerCompose.default_docker_compose_file(
                  with_env_file: true
                )
              else
                DeploymentMethod::DockerCompose.default_docker_compose_file
    end

    json(
      content: content
    )
  end

  def erase_all
    return json(result: 'success') if !@website_location || !@website_location.has_location_server?

    logs = @runner.execute([
                             { cmd_name: 'erase_repository_files', options: { path: @website.repo_dir } },
                             { cmd_name: 'ensure_remote_repository', options: { path: @website.repo_dir } }
                           ])

    @website_event_obj = { title: 'Repository cleared (erase-all)' }

    json(result: 'success')
  end

  def logs
    nb_lines = params['nbLines'].present? ? params['nbLines'].to_i : 100

    cmds = [{ cmd_name: 'logs', options: { website: @website, nb_lines: nb_lines } }]
    logs = @runner.execute(cmds)

    json(logs: logs.first[:result][:stdout])
  end

  def restart
    # run in background:
    @runner.init_execution!('Deployment')
    DeploymentMethod::Deployer.delay.run(@website_location, @runner)

    json(result: 'success', deploymentId: @runner.execution.id)
  rescue StandardError => e
    Ex::Logger.error(e, 'Issue starting deploying')
    raise e
  end

  protected

  def ensure_location
    @website_location ||= @website.website_locations.first
  end

  def requires_status_in(statuses)
    unless statuses.include?(@website.status)
      validation_error!("The instance must be in status #{statuses}.")
    end
  end

  def requires_paid_instance
    if @website.has_free_sandbox?
      validation_error!("This feature can't be used with a free sandbox.")
    end
  end

  def requires_cloud_plan
    if @website.is_private_cloud?
      validation_error!('The instance must be cloud-based for this operation.')
    end
  end

  def requires_private_cloud_plan
    unless @website.is_private_cloud?
      validation_error!('The instance must be private cloud-based for this operation.')
    end
  end

  def requires_location_server
    unless @website_location.andand.location_server
      validation_error!('This feature requires a server already allocated.')
    end
  end

  def requires_custom_domain
    unless @website.domain_type == 'custom_domain'
      validation_error!('This feature requires a custom domain.')
    end
  end

  private

  def authorize
    token = request.headers['x-auth-token'] || params['token']

    @user = User.find_by!(token: token)
  end

  def populate_website
    @website = Website.find_by! site_name: params['site_name'] if params['site_name']
  end

  def populate_website_location
    if params['location_str_id']
      @location = Location.find_by str_id: params['location_str_id']

      validation_error!('That location does not exist.') unless @location

      @website_location = @website.website_locations.find_by location_id: @location.id

      validation_error!('That location does not exist for this instance.') unless @website_location

      @location_server = @website_location.location_server
    end
  end

  def requires_minimum_cli_version
    if params['version'].blank?
      params['version'] = '0.0.0' # dummy low version
    end
  end

  def check_minimum_cli_version
    if params['version']
      unless Gem::Version.new(params['version']) >= Gem::Version.new(MINIMUM_CLI_VERSION)
        validation_error!('Deprecated CLI version, please upgrade with npm i -g openode')
      end
    end
  end

  def prepare_runner
    @runner = @website_location.prepare_runner if @website_location
  end

  def terminate_runner
    @runner.terminate if @runner.present?
  end

  def record_website_event
    @website.create_event(@website_event_obj) if @website_event_obj
  end
end
